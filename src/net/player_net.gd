class_name PlayerNet
extends Node
## Red del jugador (GDD §12). Un Player puede ser:
## - local: lo controla este peer; simula su movimiento y lo sincroniza (predicción).
## - remoto en el host: el host valida su movimiento (y lo corrige si es imposible), le
##   cobra la stamina, simula su salud/supervivencia y envía su estado a su dueño.
## - remoto en otro cliente: marioneta que sigue la sincronización.
## El estado de juego (salud, inventario, supervivencia) es siempre del host.

## Margen sobre la velocidad máxima antes de corregir (latencia, saltos, caídas).
const SPEED_TOLERANCE: float = 1.6
const SNAPSHOT_INTERVAL_S: float = 0.1

## Postura, pitch de la cabeza y si pisa suelo: los sincroniza el dueño.
var net_posture: int = 0
var net_pitch: float = 0.0
var net_on_floor: bool = true

var _player: Player
var _dirty: bool = true
var _snapshot_timer: float = 0.0
var _last_valid_position: Vector3
var _external_opened_title: String = ""


func setup(player: Player) -> void:
	_player = player
	NetSync.add(player, [":position", ":rotation", ":velocity", "PlayerNet:net_posture",
			"PlayerNet:net_pitch", "PlayerNet:net_on_floor"], player.peer_id)
	_last_valid_position = player.global_position
	if multiplayer.is_server() and not player.is_local():
		player.health.status_changed.connect(_mark_dirty)
		player.health.zone_damaged.connect(func(_z: BodyZones.Zone, _a: float) -> void: _mark_dirty())
		player.inventory.inventory_changed.connect(_mark_dirty)
		player.inventory.external_opened.connect(func(_c: ItemContainer, title: String) -> void:
			_external_opened_title = title
			_mark_dirty())
		player.weapons.weapon_changed.connect(func(_w: WeaponDefinition) -> void: _mark_dirty())
		player.weapons.ammo_changed.connect(func(_r: int, _m: int) -> void: _mark_dirty())
		player.weapons.shot_fired.connect(func(_w: WeaponDefinition) -> void: _client_shot.rpc_id(player.peer_id))
		player.weapons.reload_started.connect(func(_d: float) -> void: _client_feedback.rpc_id(player.peer_id, &"reload"))
		player.weapons.dry_fired.connect(func() -> void: _client_feedback.rpc_id(player.peer_id, &"dry_fire"))
		player.health.zone_damaged.connect(func(_z: BodyZones.Zone, amount: float) -> void:
			if amount > 0.5:
				_client_feedback.rpc_id(player.peer_id, &"hurt"))
		player.inventory.request_rejected.connect(func(reason: String) -> void: _client_rejected.rpc_id(player.peer_id, reason))


func _mark_dirty() -> void:
	_dirty = true


## Dueño: publica lo que no es transform (postura, mirada, suelo).
func publish_local() -> void:
	net_posture = _player.get_posture()
	net_pitch = _player.head_pitch()
	net_on_floor = _player.is_on_floor()


## Host, jugador remoto: valida el movimiento sincronizado y cobra la stamina.
func server_tick(delta: float) -> void:
	var moved: Vector3 = _player.global_position - _last_valid_position
	var horizontal: float = Vector2(moved.x, moved.z).length()
	var max_speed: float = _player.movement_profile.sprint_speed * SPEED_TOLERANCE + 1.0
	if horizontal > max_speed * delta + 0.5:
		# Movimiento imposible: el host corrige al cliente (GDD §12).
		_client_correct.rpc_id(_player.peer_id, _last_valid_position)
		_player.global_position = _last_valid_position
	else:
		_last_valid_position = _player.global_position
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed > _player.movement_profile.walk_speed * 1.15:
		_player.survival.drain_sprint(delta)
	# A 10 Hz (la supervivencia cambia cada tick) y al instante si cambia inventario o arma.
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0 or _dirty:
		_snapshot_timer = SNAPSHOT_INTERVAL_S
		send_snapshot()


## Host -> dueño: salud, supervivencia, inventario (con contenedores abiertos) y arma.
func send_snapshot() -> void:
	_dirty = false
	var externals: Array = []
	for container: ItemContainer in _player.inventory.inventory.external.values():
		externals.append(ItemSerializer.container_to_dict(container))
	var state: Dictionary = {"health": _player.health.to_save(),
			"survival": ItemSerializer.survival_to_dict(_player.survival),
			"inventory": ItemSerializer.inventory_to_dict(_player.inventory),
			"externals": externals, "weapon": _player.weapons.current_index,
			"reloading": _player.weapons.is_reloading(), "opened": _external_opened_title}
	_external_opened_title = ""
	_client_state.rpc_id(_player.peer_id, state)


## Dueño y marionetas: aplica postura, mirada e hitboxes sincronizadas.
func apply_remote() -> void:
	_player.apply_net_posture(net_posture, net_pitch)


@rpc("authority", "call_remote", "unreliable_ordered")
func _client_state(state: Dictionary) -> void:
	var catalog: ItemCatalog = ItemCatalog.load_default()
	_player.health.from_save(state.health)
	ItemSerializer.survival_from_dict(_player.survival, state.survival)
	ItemSerializer.inventory_from_dict(_player.inventory, state.inventory, catalog)
	var inv: Inventory = _player.inventory.inventory
	inv.external.clear()
	for data: Dictionary in state.externals:
		var container: ItemContainer = ItemSerializer.container_from_dict(data, catalog)
		inv.external[container.id] = container
	if int(state.weapon) != _player.weapons.current_index:
		_player.weapons.current_index = int(state.weapon)
		_player.weapons.weapon_changed.emit(_player.weapons.current())
	_player.weapons.ammo_changed.emit(_player.weapons.current_rounds(), 0)
	if String(state.opened) != "" and not state.externals.is_empty():
		_player.inventory.external_opened.emit(inv.external.values()[0], String(state.opened))
	_player.inventory.inventory_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _client_shot() -> void:
	_player.play_shot_feedback()


## Sonido de feedback para el dueño (recarga, cambio de arma, daño, clic en vacío).
@rpc("authority", "call_remote", "reliable")
func _client_feedback(sound: StringName) -> void:
	AudioManager.play_ui(sound)


@rpc("authority", "call_remote", "reliable")
func _client_correct(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO


@rpc("authority", "call_remote", "reliable")
func _client_respawn(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO


@rpc("authority", "call_remote", "reliable")
func _client_rejected(reason: String) -> void:
	_player.inventory.request_rejected.emit(reason)


## Host: coloca a un jugador remoto (reaparición, carga de partida).
func teleport(position: Vector3) -> void:
	_player.global_position = position
	_last_valid_position = position
	if not _player.is_local():
		_client_respawn.rpc_id(_player.peer_id, position)
