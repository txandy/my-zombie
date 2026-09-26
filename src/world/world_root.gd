extends Node3D
## Escena del mundo (GDD §12, §13). El host (también en single player) crea o carga la
## partida, construye el mundo y crea NPCs, zombis y jugadores. Un cliente recibe la seed,
## regenera el mundo localmente (es determinista), comprueba su hash con el del host y,
## cuando está listo, recibe la replicación (jugadores, zombis, objetos, bases, hora).
##
## Partida nueva: seed de SaveSystem.pending_seed, `world_seed`, `--seed=N` o aleatoria.
## Partida cargada (SaveSystem.pending_load o `--load=nombre`): el mundo sale de la caché.
## Autoguardado periódico, al salir, F5 guarda y F9 recarga (GDD §13).

signal world_ready()

## Mitad del lado de la zona de navegación alrededor de cada campamento (m).
const CAMP_NAV_HALF_SIZE_M: float = 90.0
## Cada cuánto el host envía la hora a los clientes.
const TIME_SYNC_INTERVAL_S: float = 1.0

@export var settings: WorldGenSettings
@export var world_seed: int = 0
@export var starting_kit: StartingKit
@export var player_scene: PackedScene
## Autoguardado cada N segundos (0 = desactivado). 🔶 GDD: "al dormir" pendiente de camas.
@export var autosave_interval_s: float = 300.0

var data: WorldData
var save_name: String = ""
## True si el mundo ha salido de la caché de la partida (no se ha regenerado).
var loaded_from_cache: bool = false
## Jugador de este peer.
var local_player: Player

var _autosave_left: float = 0.0
var _time_sync_left: float = 0.0
var _catalog: ItemCatalog
var _players_spawner: MultiplayerSpawner

@onready var _builder: WorldBuilder = $WorldBuilder


func _ready() -> void:
	_catalog = ItemCatalog.load_default()
	NetManager.begin_session()
	_create_spawners()
	if multiplayer.is_server():
		_start_host()
	else:
		_start_client()


# --- Host (y single player) ---

func _start_host() -> void:
	var loading: String = _resolve_load()
	var start: int = Time.get_ticks_msec()
	if loading != "":
		data = _load_world(loading)
	if data == null:
		loading = ""
		data = WorldGenerator.generate(_resolve_seed(), settings)
	GameState.start_session(data.world_seed)
	_build_world(start, "caché" if loading != "" else "generación")
	local_player = _players_spawner.spawn({"peer": 1, "name": "Player", "pos": data.spawns.player_spawn}) as Player
	loaded_from_cache = loading != ""
	if loading != "":
		save_name = loading
		_restore_state()
	else:
		save_name = "partida_%d" % data.world_seed
		SaveSystem.write_world(save_name, WorldCache.to_dict(data))
		save_game()
	SaveSystem.current_save = save_name
	SaveSystem.pending_load = ""
	SaveSystem.pending_seed = 0
	_autosave_left = autosave_interval_s
	multiplayer.peer_disconnected.connect(_on_peer_left)
	Ballistics.projectile_impacted.connect(_on_impact)
	EventBus.sound_emitted.connect(_relay_sound)
	EventBus.horde_started.connect(func() -> void:
		for peer: int in NetManager.ready_clients():
			_client_horde.rpc_id(peer))
	world_ready.emit()


func _resolve_load() -> String:
	if SaveSystem.pending_load != "":
		return SaveSystem.pending_load
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--load="):
			return arg.trim_prefix("--load=")
	return ""


func _resolve_seed() -> int:
	if SaveSystem.pending_seed != 0:
		return SaveSystem.pending_seed
	if world_seed != 0:
		return world_seed
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return GameState.random_world_seed()


func _load_world(name_to_load: String) -> WorldData:
	var cached: Dictionary = SaveSystem.read_world(name_to_load)
	if cached.is_empty():
		push_error("Partida '%s': no hay caché del mundo" % name_to_load)
		return null
	return WorldCache.from_dict(cached)


## Construye terreno, POIs, vegetación, bases, campamentos y director de zombis.
## Es igual en el host y en los clientes (los nodos deben tener las mismas rutas).
func _build_world(start_msec: int, source: String) -> void:
	var generated: int = Time.get_ticks_msec()
	_builder.build(data, settings)
	print("Mundo seed=%d · %s %d ms · construcción %d ms · hash %s" % [data.world_seed, source,
			generated - start_msec, Time.get_ticks_msec() - generated, data.compute_hash().left(12)])
	var buildings := BuildingManager.new()
	buildings.name = "Buildings"
	add_child(buildings)
	_spawn_npcs()


# --- Cliente ---

func _start_client() -> void:
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await multiplayer.connected_to_server
	_server_hello.rpc_id(1, NetManager.player_name)


@rpc("any_peer", "call_remote", "reliable")
func _server_hello(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	NetManager.peer_names[peer] = player_name.validate_filename()
	_client_setup.rpc_id(peer, data.world_seed, data.compute_hash())


@rpc("authority", "call_remote", "reliable")
func _client_setup(seed_value: int, expected_hash: String) -> void:
	var start: int = Time.get_ticks_msec()
	GameState.world_seed = seed_value
	data = WorldGenerator.generate(seed_value, settings)
	if data.compute_hash() != expected_hash:
		push_error("Desincronización: el mundo generado no coincide con el del host")
		NetManager.close()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	_build_world(start, "generación (cliente)")
	_server_client_ready.rpc_id(1)
	world_ready.emit()


@rpc("any_peer", "call_remote", "reliable")
func _server_client_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	NetManager.mark_ready(peer)
	var player := _players_spawner.spawn({"peer": peer, "name": "Player_%d" % peer,
			"pos": data.spawns.player_spawn + Vector3(2, 0, 0)}) as Player
	var saved: Dictionary = SaveSystem.read_player(save_name, NetManager.peer_names.get(peer, "")) if save_name != "" else {}
	if not saved.is_empty():
		WorldPersistence.apply_player(player, saved, _catalog)
		player.net.teleport(saved.pos as Vector3)
	(get_node(^"Buildings") as BuildingManager).send_full_state(peer)
	_client_time.rpc_id(peer, GameState.day, GameState.hour)


func _on_peer_left(peer: int) -> void:
	var player := get_node_or_null("Player_%d" % peer) as Player
	if player != null:
		_save_player(player, NetManager.peer_names.get(peer, "peer_%d" % peer))
		player.queue_free()


# --- Spawners (jugadores y objetos en el suelo) ---

func _create_spawners() -> void:
	_players_spawner = MultiplayerSpawner.new()
	_players_spawner.name = "PlayersSpawner"
	_players_spawner.spawn_function = _spawn_player
	add_child(_players_spawner)
	_players_spawner.spawn_path = _players_spawner.get_path_to(self)
	var items := WorldItems.new()
	items.name = "Items"
	add_child(items)


func _spawn_player(spawn: Dictionary) -> Node:
	var player := player_scene.instantiate() as Player
	player.name = String(spawn.name)
	player.peer_id = int(spawn.peer)
	player.starting_kit = starting_kit
	player.position = spawn.pos
	player.spawn_point = spawn.pos
	player.ready.connect(func() -> void:
		player.survival.climate_sampler = _climate_at
		if player.is_local():
			local_player = player
			var overlay := get_node_or_null(^"DebugOverlay")
			if overlay != null:
				overlay.set(&"target", player))
	return player


# --- Hora, impactos y guardado ---

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_time_sync_left -= delta
	if _time_sync_left <= 0.0:
		_time_sync_left = TIME_SYNC_INTERVAL_S
		for peer: int in NetManager.ready_clients():
			_client_time.rpc_id(peer, GameState.day, GameState.hour)
	if autosave_interval_s > 0.0:
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			_autosave_left = autosave_interval_s
			save_game()


@rpc("authority", "call_remote", "unreliable_ordered")
func _client_time(day: int, hour: float) -> void:
	if day != GameState.day:
		EventBus.day_started.emit(day)
	GameState.day = day
	GameState.hour = hour
	var cycle := get_node_or_null(^"DayNightCycle") as DayNightCycle
	var night: bool = cycle.is_night_at(hour) if cycle != null else false
	if night != GameState.is_night:
		GameState.is_night = night
		EventBus.night_changed.emit(night)


func _on_impact(position: Vector3, normal: Vector3, hitbox: Hitbox, source: Node) -> void:
	var hitbox_path: NodePath = hitbox.get_path() if hitbox != null else NodePath()
	var source_path: NodePath = source.get_path() if source != null and source.is_inside_tree() else NodePath()
	for peer: int in NetManager.ready_clients():
		_client_impact.rpc_id(peer, position, normal, hitbox_path, source_path)


@rpc("authority", "call_remote", "unreliable")
func _client_impact(position: Vector3, normal: Vector3, hitbox_path: NodePath, source_path: NodePath) -> void:
	var hitbox := get_node_or_null(hitbox_path) as Hitbox if not hitbox_path.is_empty() else null
	var source := get_node_or_null(source_path) if not source_path.is_empty() else null
	Ballistics.projectile_impacted.emit(position, normal, hitbox, source)


func _unhandled_input(event: InputEvent) -> void:
	if not multiplayer.is_server():
		return
	if event.is_action_pressed(&"quick_save"):
		save_game()
	elif event.is_action_pressed(&"quick_load") and SaveSystem.exists(save_name) and not NetManager.is_online():
		SaveSystem.pending_load = save_name
		get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_name != "" and multiplayer.is_server():
		save_game()


## Guarda el estado dinámico y el de todos los jugadores (solo el host). Un archivo por
## jugador: el host es "host" y los clientes, su nombre.
func save_game() -> Error:
	if not multiplayer.is_server() or save_name == "":
		return ERR_UNAVAILABLE
	var meta: Dictionary = {"seed": data.world_seed, "day": GameState.day, "hour": GameState.hour,
			"world_hash": data.compute_hash()}
	var players: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Player
		players[_player_id(player)] = WorldPersistence.capture_player(player)
	var err: Error = SaveSystem.write_state(save_name, meta, WorldPersistence.capture(self), players)
	print("Partida '%s' guardada (%s)" % [save_name, error_string(err)])
	return err


func _save_player(player: Player, player_id: String) -> void:
	if save_name != "":
		SaveSystem.write_state(save_name, SaveSystem.read_meta(save_name), WorldPersistence.capture(self),
				{player_id: WorldPersistence.capture_player(player)})


func _player_id(player: Player) -> String:
	return "host" if player.peer_id == 1 else NetManager.peer_names.get(player.peer_id, "peer_%d" % player.peer_id)


func _restore_state() -> void:
	var state: Dictionary = SaveSystem.read_state(save_name)
	if not state.is_empty():
		WorldPersistence.apply(self, state, _catalog)
	var player_state: Dictionary = SaveSystem.read_player(save_name, "host")
	if not player_state.is_empty():
		WorldPersistence.apply_player(local_player, player_state, _catalog)


# --- NPCs y zombis ---

func _spawn_npcs() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)
	var manager := AIManager.new()
	manager.name = "AIManager"
	add_child(manager)
	var registry := _builder.get_node(^"CoverRegistry") as CoverRegistry
	for i: int in data.spawns.camps.size():
		var camp: SpawnData.Camp = data.spawns.camps[i]
		if multiplayer.is_server():
			NavRegionBuilder.bake(npcs, camp.position, CAMP_NAV_HALF_SIZE_M, _builder.terrain,
					_builder.get_node(^"POIs"), registry)
		CampSpawner.spawn_camp(npcs, camp, i, settings.npc_archetypes[camp.archetype_index], _height_at)
	manager.update_lods()
	var director := ZombieDirector.new()
	director.name = "Zombies"
	director.zombie_scene = load("res://scenes/ai/zombie.tscn") as PackedScene
	director.cycle = $DayNightCycle as DayNightCycle
	director.spawn_points = data.spawns.zombie_points
	add_child(director)


func _height_at(point: Vector3) -> float:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.height_at(x, z)


## Temperatura normalizada (0-1) del clima generado en un punto (para la supervivencia).
func _climate_at(point: Vector3) -> float:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.temperature[data.index(x, z)]


# --- Sonido en coop: los eventos de sonido ocurren en el host y se reenvían ---

func _relay_sound(position: Vector3, _radius_m: float, kind: StringName, _source: Node) -> void:
	for peer: int in NetManager.ready_clients():
		_client_sound.rpc_id(peer, position, kind)


@rpc("authority", "call_remote", "unreliable")
func _client_sound(position: Vector3, kind: StringName) -> void:
	AudioManager.play_at(AudioManager.sound_for_event(kind), position)


@rpc("authority", "call_remote", "reliable")
func _client_horde() -> void:
	EventBus.horde_started.emit()
