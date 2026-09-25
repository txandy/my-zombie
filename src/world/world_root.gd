extends Node3D
## Escena del mundo: arranca una sesión single player (host sin clientes), crea o carga
## la partida, construye el mundo, coloca al jugador y crea NPCs y zombis.
##
## Partida nueva: seed de SaveSystem.pending_seed, `world_seed`, `--seed=N` o aleatoria;
## se genera el mundo y se guarda su caché. Partida cargada (SaveSystem.pending_load o
## `--load=nombre`): el mundo sale de la caché (no se regenera) y se restaura el estado.
## Autoguardado periódico, al salir, F5 guarda y F9 recarga la última partida (GDD §13).

## Mitad del lado de la zona de navegación alrededor de cada campamento (m).
const CAMP_NAV_HALF_SIZE_M: float = 90.0
const HOST_PLAYER_ID: String = "host"

@export var settings: WorldGenSettings
@export var world_seed: int = 0
## Autoguardado cada N segundos (0 = desactivado). 🔶 GDD: "al dormir" pendiente de camas.
@export var autosave_interval_s: float = 300.0

var data: WorldData
var save_name: String = ""
## True si el mundo ha salido de la caché de la partida (no se ha regenerado).
var loaded_from_cache: bool = false

var _autosave_left: float = 0.0
var _catalog: ItemCatalog

@onready var _builder: WorldBuilder = $WorldBuilder
@onready var _player: Player = $Player


func _ready() -> void:
	NetManager.start_single_player()
	_catalog = ItemCatalog.load_default()
	var loading: String = _resolve_load()
	var start: int = Time.get_ticks_msec()
	if loading != "":
		data = _load_world(loading)
	if data == null:
		loading = ""
		data = WorldGenerator.generate(_resolve_seed(), settings)
	GameState.start_session(data.world_seed)
	var generated: int = Time.get_ticks_msec()
	_builder.build(data, settings)
	print("Mundo seed=%d · %s %d ms · construcción %d ms · hash %s" % [data.world_seed,
			"caché" if loading != "" else "generación", generated - start, Time.get_ticks_msec() - generated,
			data.compute_hash().left(12)])

	_player.global_position = data.spawns.player_spawn
	_player.spawn_point = _player.global_position
	_player.survival.climate_sampler = _climate_at
	var buildings := BuildingManager.new()
	buildings.name = "Buildings"
	add_child(buildings)
	_spawn_npcs()
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


# --- Guardado ---

func _process(delta: float) -> void:
	if autosave_interval_s <= 0.0 or not multiplayer.is_server():
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = autosave_interval_s
		save_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		save_game()
	elif event.is_action_pressed(&"quick_load") and SaveSystem.exists(save_name):
		SaveSystem.pending_load = save_name
		get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_name != "":
		save_game()


## Guarda el estado dinámico y el del jugador (solo el host).
func save_game() -> Error:
	if not multiplayer.is_server() or save_name == "":
		return ERR_UNAVAILABLE
	var meta: Dictionary = {"seed": data.world_seed, "day": GameState.day, "hour": GameState.hour,
			"world_hash": data.compute_hash()}
	var players: Dictionary = {HOST_PLAYER_ID: WorldPersistence.capture_player(_player)}
	var err: Error = SaveSystem.write_state(save_name, meta, WorldPersistence.capture(self), players)
	print("Partida '%s' guardada (%s)" % [save_name, error_string(err)])
	return err


func _restore_state() -> void:
	var state: Dictionary = SaveSystem.read_state(save_name)
	if not state.is_empty():
		WorldPersistence.apply(self, state, _catalog)
	var player_state: Dictionary = SaveSystem.read_player(save_name, HOST_PLAYER_ID)
	if not player_state.is_empty():
		WorldPersistence.apply_player(_player, player_state, _catalog)


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
		NavRegionBuilder.bake(npcs, camp.position, CAMP_NAV_HALF_SIZE_M, _builder.terrain,
				_builder.get_node(^"POIs"), registry)
		CampSpawner.spawn_camp(npcs, camp, i, settings.npc_archetypes[camp.archetype_index], _height_at)
	manager.update_lods()
	_spawn_zombies()


func _spawn_zombies() -> void:
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
