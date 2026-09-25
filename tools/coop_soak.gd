extends Node
## Prueba de resistencia del coop (criterio de M7, GDD §17): dos procesos reales (host y
## cliente por ENet) juegan un día acelerado y comparan periódicamente su estado.
## El host lanza el proceso cliente, y los dos ejecutan un guion (moverse, disparar,
## construir, tirar objetos). Cada CHECK_INTERVAL_S el cliente envía su visión del mundo
## y el host la compara con la suya. Desincronización = una diferencia que persiste en
## dos comprobaciones seguidas (se tolera la latencia normal de la replicación).
## Uso: godot --headless --path . res://tools/coop_soak.tscn -- --seed=12345
## Sale con código 0 si no hay desincronizaciones.

const DAY_S: float = 120.0
const CHECK_INTERVAL_S: float = 5.0
const PORT: int = 24599
const WORLD_SCENE: String = "res://scenes/world/world.tscn"

var _is_host: bool = true
var _world: Node3D
var _elapsed: float = 0.0
var _check_left: float = CHECK_INTERVAL_S
var _started: bool = false
var _client_pid: int = -1
var _checks: int = 0
var _failures_in_a_row: Dictionary[String, int] = {}
var _desyncs: PackedStringArray = []
var _built: bool = false
var _dropped: bool = false
var _client_built: bool = false
var _max_zombies: int = 0
var _shots: int = 0
var _last_counts: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--role=client":
			_is_host = false
	if _is_host:
		NetManager.mode = NetManager.Mode.HOST
		NetManager.port = PORT
		var seed_value: int = 12345
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--seed="):
				seed_value = arg.trim_prefix("--seed=").to_int()
		SaveSystem.pending_seed = seed_value
		NetManager.peer_ready.connect(func(_peer: int) -> void: _started = true)
	else:
		NetManager.mode = NetManager.Mode.CLIENT
		NetManager.join_address = "127.0.0.1"
		NetManager.port = PORT
		NetManager.player_name = "Cliente"
		multiplayer.server_disconnected.connect(get_tree().quit)
	_world = (load(WORLD_SCENE) as PackedScene).instantiate() as Node3D
	_world.set(&"autosave_interval_s", 0.0)
	add_child(_world)
	if _is_host:
		_launch_client()
	else:
		_world.connect(&"world_ready", func() -> void: _started = true)


func _launch_client() -> void:
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"res://tools/coop_soak.tscn", "--", "--role=client"]
	_client_pid = OS.create_process(OS.get_executable_path(), args)
	print("COOP host: cliente lanzado (pid %d)" % _client_pid)


func _physics_process(delta: float) -> void:
	if not _started:
		return
	if _elapsed == 0.0 and _is_host:
		var cycle := _world.get_node("DayNightCycle") as DayNightCycle
		cycle.time_scale = cycle.settings.day_length_s / DAY_S
		GameState.game_hours_per_second = 24.0 / DAY_S
		GameState.hour = 12.0
		_give_resources()
		print("COOP host: cliente listo; empieza el día acelerado (%.0f s)" % DAY_S)
	_elapsed += delta
	_script_local_player(delta)
	if _is_host:
		_max_zombies = maxi(_max_zombies, get_tree().get_nodes_in_group(&"zombie").size())
		_check_left -= delta
		if _check_left <= 0.0:
			_check_left = CHECK_INTERVAL_S
			_request_client_view.rpc_id(_client_peer())
		if _elapsed >= DAY_S + 10.0:
			_finish()


# --- Guion de juego ---

func _local_player() -> Player:
	return _world.get(&"local_player") as Player


func _script_local_player(delta: float) -> void:
	var player: Player = _local_player()
	if player == null or player.health.is_dead:
		return
	var frame := PlayerInputFrame.new()
	# Pasea en círculo alrededor de su punto de aparición.
	var phase: float = _elapsed * 0.3 + (0.0 if _is_host else PI)
	var goal: Vector3 = player.spawn_point + Vector3(cos(phase), 0, sin(phase)) * 8.0
	var to_goal: Vector3 = goal - player.global_position
	to_goal.y = 0.0
	if to_goal.length() > 1.0:
		var local_dir: Vector3 = player.global_basis.inverse() * to_goal.normalized()
		frame.move = Vector2(local_dir.x, -local_dir.z)
	# Dispara al zombi vivo más cercano si lo hay a tiro.
	var zombie: Node3D = _nearest_zombie(player, 120.0)
	if zombie != null and fmod(_elapsed, 1.5) < delta:
		var cam: Camera3D = player.camera()
		player.weapons.request_attack(cam.global_position, (zombie.global_position + Vector3.UP * 1.3 - cam.global_position).normalized(), true)
		_shots += 1
	player.step(frame, delta)
	if _elapsed > 15.0 and not _built and _is_host:
		_built = true
		_build(player)
	if _elapsed > 25.0 and not _client_built and not _is_host:
		_client_built = true
		_build(player)
	if _elapsed > 20.0 and not _dropped and _is_host:
		_dropped = true
		var bandage: ItemInstance = _find_item(player, &"bandage")
		if bandage != null:
			player.inventory.request_drop(bandage.uuid)


func _build(player: Player) -> void:
	var foundation := load("res://data/building/pieces/foundation.tres") as BuildingPieceDefinition
	var wood := load("res://data/building/materials/wood.tres") as BuildingMaterial
	var manager := _world.get_node("Buildings") as BuildingManager
	for attempt: int in 36:
		var radius: float = 4.0 + float(attempt / 12) * 2.0
		var probe: Vector3 = player.global_position + Vector3(cos(attempt * 0.52), 0, sin(attempt * 0.52)) * radius - Vector3.UP
		if manager.placement_error(foundation, manager.resolve_slot(foundation, probe, 0.0)) == "":
			manager.request_place(player, foundation, wood, probe, 0.0)
			return
	print("COOP %s: no encuentra sitio para construir" % ("host" if _is_host else "cliente"))


func _give_resources() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Player
		player.inventory.inventory.equip(ItemInstance.new(load("res://data/items/backpack_large.tres") as ItemDefinition), Inventory.Slot.BACKPACK)
		player.inventory.give(ItemInstance.new(load("res://data/items/wood.tres") as ItemDefinition, 100))
		player.inventory.give(ItemInstance.new(load("res://data/items/canned_food.tres") as ItemDefinition))


func _nearest_zombie(player: Player, max_distance: float) -> Node3D:
	var best: Node3D = null
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		var zombie := node as Zombie
		if zombie.state == Zombie.State.DEAD:
			continue
		var d: float = zombie.global_position.distance_to(player.global_position)
		if d < max_distance and (best == null or d < best.global_position.distance_to(player.global_position)):
			best = zombie
	return best


func _find_item(player: Player, id: StringName) -> ItemInstance:
	for container: ItemContainer in player.inventory.inventory.storage():
		for item: ItemInstance in container.items():
			if item.definition.id == id:
				return item
	return null


func _client_peer() -> int:
	var clients: Array[int] = NetManager.ready_clients()
	return clients[0] if not clients.is_empty() else 0


# --- Visión del mundo y comparación ---

## Estado replicado visto por este peer.
func _view() -> Dictionary:
	var players: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Player
		players[String(player.name)] = {"pos": player.global_position, "thorax": player.health.hp(BodyZones.Zone.THORAX),
				"dead": player.health.is_dead}
	var zombies: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		var zombie := node as Zombie
		zombies[String(zombie.name)] = {"pos": zombie.global_position, "dead": zombie.state == Zombie.State.DEAD}
	var npcs: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		npcs[String(node.name)] = {"pos": (node as Node3D).global_position, "dead": (node as HumanNPC).is_dead}
	var pieces: Dictionary = {}
	var manager := _world.get_node("Buildings") as BuildingManager
	for base: BaseModel in manager.bases:
		for piece: BaseModel.Piece in base.pieces.values():
			pieces["%d:%d" % [base.id, piece.uid]] = {"hp": piece.hp, "def": String(piece.definition.id)}
	var items: Array = []
	for node: Node in get_tree().get_nodes_in_group(&"world_item"):
		items.append(String(node.name))
	var client_inventory: Dictionary = {}
	var client_player := _world.get_node_or_null("Player_%d" % (multiplayer.get_unique_id() if not _is_host else _client_peer())) as Player
	if client_player != null:
		for container: ItemContainer in client_player.inventory.inventory.storage():
			for item: ItemInstance in container.items():
				client_inventory[String(item.uuid)] = item.quantity
	return {"day": GameState.day, "hour": GameState.hour, "players": players, "zombies": zombies,
			"npcs": npcs, "pieces": pieces, "items": items, "client_inventory": client_inventory}


@rpc("authority", "call_remote", "reliable")
func _request_client_view() -> void:
	_receive_client_view.rpc_id(1, _view())


@rpc("any_peer", "call_remote", "reliable")
func _receive_client_view(client: Dictionary) -> void:
	_checks += 1
	var host: Dictionary = _view()
	_last_counts = "jugadores %d/%d · zombis %d/%d · npcs %d/%d · piezas %d/%d · objetos %d/%d · inv. cliente %d/%d" % [
			host.players.size(), client.players.size(), host.zombies.size(), client.zombies.size(),
			host.npcs.size(), client.npcs.size(), host.pieces.size(), client.pieces.size(),
			(host.items as Array).size(), (client.items as Array).size(), host.client_inventory.size(), client.client_inventory.size()]
	var problems: Dictionary[String, String] = {}
	if int(client.day) != int(host.day) and absf(float(client.hour) - float(host.hour)) < 23.0:
		problems["día"] = "%d vs %d" % [host.day, client.day]
	elif absf(float(client.hour) - float(host.hour)) > 0.5 and absf(float(client.hour) - float(host.hour)) < 23.5:
		problems["hora"] = "%.2f vs %.2f" % [host.hour, client.hour]
	_compare_positions(problems, "jugador", host.players, client.players, 2.0, 0)
	_compare_positions(problems, "zombi", host.zombies, client.zombies, 3.0, 2)
	_compare_positions(problems, "npc", host.npcs, client.npcs, 2.5, 0)
	_compare_keys(problems, "piezas", host.pieces, client.pieces, 0)
	for key: String in host.pieces:
		if client.pieces.has(key) and absf(float(host.pieces[key].hp) - float(client.pieces[key].hp)) > 1.0:
			problems["vida pieza " + key] = "%.0f vs %.0f" % [host.pieces[key].hp, client.pieces[key].hp]
	if (host.items as Array).size() != (client.items as Array).size():
		problems["objetos suelo"] = "%d vs %d" % [(host.items as Array).size(), (client.items as Array).size()]
	if host.client_inventory != client.client_inventory:
		problems["inventario cliente"] = "%s vs %s" % [host.client_inventory, client.client_inventory]
	_record(problems)


func _compare_positions(problems: Dictionary[String, String], label: String, host: Dictionary, client: Dictionary,
		tolerance_m: float, allowed_missing: int) -> void:
	_compare_keys(problems, label, host, client, allowed_missing)
	for key: String in host:
		if not client.has(key):
			continue
		if bool(host[key].dead) != bool(client[key].dead):
			problems["%s %s muerto" % [label, key]] = "%s vs %s" % [host[key].dead, client[key].dead]
		var distance: float = (host[key].pos as Vector3).distance_to(client[key].pos as Vector3)
		if distance > tolerance_m:
			problems["%s %s posición" % [label, key]] = "%.1f m" % distance


func _compare_keys(problems: Dictionary[String, String], label: String, host: Dictionary, client: Dictionary,
		allowed_missing: int) -> void:
	var missing: int = 0
	for key: String in host:
		if not client.has(key):
			missing += 1
	for key: String in client:
		if not host.has(key):
			missing += 1
	if missing > allowed_missing:
		problems[label + " (conjunto)"] = "%d distintos" % missing


func _record(problems: Dictionary[String, String]) -> void:
	for key: String in _failures_in_a_row.keys():
		if not problems.has(key):
			_failures_in_a_row.erase(key)
	for key: String in problems:
		_failures_in_a_row[key] = _failures_in_a_row.get(key, 0) + 1
		if _failures_in_a_row[key] == 2:
			_desyncs.append("t=%.0fs %s: %s" % [_elapsed, key, problems[key]])
	print("COOP check %d (t=%.0f s, día %d %05.2f h): %s" % [_checks, _elapsed, GameState.day, GameState.hour,
			"ok" if problems.is_empty() else "diferencias transitorias %s" % problems.keys()])
	if _checks == 1 or _checks % 8 == 0:
		print("COOP   comparado: %s" % _last_counts)


func _finish() -> void:
	var manager := _world.get_node("Buildings") as BuildingManager
	var pieces: int = 0
	for base: BaseModel in manager.bases:
		pieces += base.pieces.size()
	print("COOP ---- Resultado ----")
	print("COOP día final %d · comprobaciones %d · desincronizaciones %d" % [GameState.day, _checks, _desyncs.size()])
	print("COOP jugadores %d · piezas construidas %d · zombis máx. %d · disparos del host %d" % [
			get_tree().get_nodes_in_group(&"player").size(), pieces, _max_zombies, _shots])
	for line: String in _desyncs:
		print("COOP DESYNC ", line)
	if _client_pid > 0:
		OS.kill(_client_pid)
	SaveSystem.delete_save(String(_world.get(&"save_name")))
	get_tree().quit(1 if not _desyncs.is_empty() or _checks == 0 else 0)
