class_name WeaponHolder
extends Node
## Armas que lleva un personaje y su uso: disparo, cadencia, cargador, recarga, cambio
## de arma y cuerpo a cuerpo. Mismo componente para el jugador y los NPCs (AGENTS.md §1.5).
##
## Cada arma es un ItemInstance; las balas cargadas viven en su estado ("rounds", "ammo"),
## así se conservan al guardarla, soltarla o recogerla.
## La recarga toma balas sueltas del `ammo_provider` (el inventario). Sin proveedor
## (dummies de pruebas) la munición de reserva es infinita.
##
## Patrón de red (AGENTS.md §4): el dueño pide con request_*() y el host valida y aplica.
## La dispersión se calcula en el host con su RNG de combate.

## Host: se ha disparado (para retroceso, sonido y animación).
signal shot_fired(weapon: WeaponDefinition)
## Host: golpe cuerpo a cuerpo ejecutado.
signal melee_swung(weapon: WeaponDefinition)
signal weapon_changed(weapon: WeaponDefinition)
signal ammo_changed(rounds: int, magazine_size: int)
signal reload_started(duration_s: float)
## Host: no hay munición compatible para recargar.
signal reload_failed()

## Armas fijas para personajes sin inventario (dummies). Se cargan llenas.
@export var loadout: Array[WeaponDefinition] = []
## Salud del portador: sus heridas en los brazos afectan a dispersión y recarga. Opcional.
@export var health: HealthComponent
## Nodo cuyas hitboxes y cuerpo ignoran sus propias balas.
@export var damage_receiver: DamageReceiver
@export var body: CollisionObject3D
## Peer dueño de este personaje (1 = host). Solo él puede pedir acciones.
@export var owner_peer_id: int = 1

## Tolerancia de los temporizadores: evita que un residuo de coma flotante (p. ej. 0.1 - 6/60)
## retrase la acción un tick entero y baje la cadencia real.
const TIMER_EPSILON: float = 0.0001

## Proveedor de munición: objeto con count_ammo(id), take_ammo(id, n),
## ammo_types_for(calibre) y return_ammo(munición, n). Null = reserva infinita.
var ammo_provider: Object
## Un arma por slot (puede haber huecos vacíos).
var slots: Array[ItemInstance] = []
var current_index: int = 0

var _cooldown_s: float = 0.0
var _reload_left_s: float = 0.0
var _reload_ammo: AmmoDefinition


func _ready() -> void:
	if not loadout.is_empty():
		var items: Array[ItemInstance] = []
		for weapon: WeaponDefinition in loadout:
			items.append(make_weapon_item(weapon))
		set_weapon_items(items)


func _physics_process(delta: float) -> void:
	_cooldown_s = maxf(_cooldown_s - delta, 0.0)
	if _reload_left_s > 0.0:
		_reload_left_s -= delta
		if _reload_left_s <= TIMER_EPSILON:
			_finish_reload()


## Crea un objeto de arma (sin definición de objeto propia) con el cargador lleno.
static func make_weapon_item(weapon: WeaponDefinition) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = weapon.id
	def.display_name = weapon.display_name
	def.category = ItemDefinition.Category.WEAPON
	def.weapon = weapon
	var item := ItemInstance.new(def)
	load_full(item)
	return item


## Deja el arma con el cargador lleno de su munición por defecto.
static func load_full(item: ItemInstance) -> void:
	var weapon: WeaponDefinition = item.definition.weapon
	if weapon.kind == WeaponDefinition.Kind.FIREARM:
		item.state["rounds"] = weapon.magazine_size
		item.state["ammo"] = weapon.default_ammo


## Cambia las armas disponibles (p. ej. al cambiar el equipo). Mantiene el slot actual si sigue ocupado.
func set_weapon_items(items: Array[ItemInstance]) -> void:
	var previous: ItemInstance = current_item()
	slots = items.duplicate()
	if current_item() != previous or previous == null:
		_reload_left_s = 0.0
		current_index = maxi(_first_occupied_slot(), 0)
		weapon_changed.emit(current())
	ammo_changed.emit(current_rounds(), _magazine_size())


func current_item() -> ItemInstance:
	return slots[current_index] if current_index < slots.size() else null


func current() -> WeaponDefinition:
	var item: ItemInstance = current_item()
	return item.definition.weapon if item != null else null


func loaded_ammo() -> AmmoDefinition:
	var item: ItemInstance = current_item()
	if item == null or current().kind != WeaponDefinition.Kind.FIREARM:
		return null
	return item.state.get("ammo", current().default_ammo) as AmmoDefinition


func is_reloading() -> bool:
	return _reload_left_s > 0.0


func current_rounds() -> int:
	var item: ItemInstance = current_item()
	return int(item.state.get("rounds", 0)) if item != null else 0


func reserve_ammo() -> int:
	var ammo: AmmoDefinition = loaded_ammo()
	if ammo == null:
		return 0
	return int(ammo_provider.call(&"count_ammo", ammo.id)) if ammo_provider != null else -1


func _magazine_size() -> int:
	return current().magazine_size if current() != null else 0


func _first_occupied_slot() -> int:
	for i: int in slots.size():
		if slots[i] != null:
			return i
	return -1


# --- Solicitudes (dueño -> host) ---

## Dispara (arma de fuego) o golpea (cuerpo a cuerpo) desde `origin` hacia `direction`.
func request_attack(origin: Vector3, direction: Vector3, aiming: bool) -> void:
	_server_attack.rpc_id(1, origin, direction, aiming)


func request_reload() -> void:
	_server_reload.rpc_id(1)


func request_switch(index: int) -> void:
	_server_switch.rpc_id(1, index)


@rpc("any_peer", "call_local", "reliable")
func _server_attack(origin: Vector3, direction: Vector3, aiming: bool) -> void:
	if not _is_valid_request() or _cooldown_s > TIMER_EPSILON or is_reloading():
		return
	var weapon: WeaponDefinition = current()
	if weapon == null:
		return
	if weapon.kind == WeaponDefinition.Kind.MELEE:
		_melee(weapon, origin, direction)
		return
	var item: ItemInstance = current_item()
	var rounds: int = current_rounds()
	if rounds <= 0:
		return
	item.state["rounds"] = rounds - 1
	_cooldown_s = weapon.fire_interval_s()
	var ammo: AmmoDefinition = loaded_ammo()
	for i: int in ammo.projectile_count:
		Ballistics.fire(origin, spread_direction(direction, spread_angle(weapon, aiming), Ballistics.rng),
				ammo, get_parent(), _exclude_rids())
	EventBus.sound_emitted.emit(origin, weapon.shot_sound_radius_m, &"gunshot", get_parent())
	shot_fired.emit(weapon)
	ammo_changed.emit(rounds - 1, weapon.magazine_size)


@rpc("any_peer", "call_local", "reliable")
func _server_reload() -> void:
	var weapon: WeaponDefinition = current()
	if not _is_valid_request() or weapon == null or weapon.kind != WeaponDefinition.Kind.FIREARM:
		return
	if is_reloading() or current_rounds() >= weapon.magazine_size and _has_ammo(loaded_ammo()):
		return
	_reload_ammo = _choose_reload_ammo(weapon)
	if _reload_ammo == null:
		reload_failed.emit()
		return
	var multiplier: float = health.reload_multiplier() if health != null else 1.0
	_reload_left_s = weapon.reload_time_s / multiplier
	reload_started.emit(_reload_left_s)


@rpc("any_peer", "call_local", "reliable")
func _server_switch(index: int) -> void:
	if not _is_valid_request() or index < 0 or index >= slots.size() or index == current_index:
		return
	if slots[index] == null:
		return
	current_index = index
	_reload_left_s = 0.0
	# Sacar el arma lleva un momento: no se puede atacar en el mismo tick.
	_cooldown_s = maxf(_cooldown_s, 0.25)
	weapon_changed.emit(current())
	ammo_changed.emit(current_rounds(), _magazine_size())


func _is_valid_request() -> bool:
	if not multiplayer.is_server():
		return false
	if health != null and health.is_dead:
		return false
	var sender: int = multiplayer.get_remote_sender_id()
	# 0 = llamada local directa (sin RPC); en ese caso actúa el propio host.
	return sender == owner_peer_id or (sender == 0 and owner_peer_id == multiplayer.get_unique_id())


func _has_ammo(ammo: AmmoDefinition) -> bool:
	return ammo_provider == null or ammo != null and int(ammo_provider.call(&"count_ammo", ammo.id)) > 0


## Munición a cargar: la misma que lleva si queda; si no, la primera compatible disponible.
func _choose_reload_ammo(weapon: WeaponDefinition) -> AmmoDefinition:
	var loaded: AmmoDefinition = loaded_ammo()
	if ammo_provider == null:
		return loaded
	if loaded != null and _has_ammo(loaded) and current_rounds() < weapon.magazine_size:
		return loaded
	for ammo: AmmoDefinition in ammo_provider.call(&"ammo_types_for", weapon.caliber) as Array:
		if ammo != loaded:
			return ammo
	return null


func _finish_reload() -> void:
	_reload_left_s = 0.0
	var item: ItemInstance = current_item()
	var weapon: WeaponDefinition = current()
	if item == null or _reload_ammo == null:
		return
	var rounds: int = current_rounds()
	if ammo_provider == null:
		rounds = weapon.magazine_size
	else:
		if _reload_ammo != loaded_ammo() and rounds > 0:
			# Cambio de tipo: las balas que quedaban vuelven al inventario.
			ammo_provider.call(&"return_ammo", loaded_ammo(), rounds)
			rounds = 0
		rounds += int(ammo_provider.call(&"take_ammo", _reload_ammo.id, weapon.magazine_size - rounds))
	item.state["rounds"] = rounds
	item.state["ammo"] = _reload_ammo
	ammo_changed.emit(rounds, weapon.magazine_size)


func _melee(weapon: WeaponDefinition, origin: Vector3, direction: Vector3) -> void:
	_cooldown_s = weapon.melee_interval_s
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * weapon.melee_range_m,
			PhysicsLayers.PROJECTILE_MASK, _exclude_rids())
	query.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(query)
	var hitbox := hit.get("collider") as Hitbox
	if hitbox != null and hitbox.receiver != null:
		hitbox.receiver.receive_melee(hitbox.zone, weapon.melee_damage, get_parent(), Ballistics.rng)
	melee_swung.emit(weapon)


func _exclude_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if damage_receiver != null:
		rids = damage_receiver.hitbox_rids()
	if body != null:
		rids.append(body.get_rid())
	return rids


## Semiángulo del cono de dispersión en radianes (1 MOA = 1/60 de grado).
func spread_angle(weapon: WeaponDefinition, aiming: bool) -> float:
	var moa: float = weapon.spread_moa * (1.0 if aiming else weapon.hip_spread_multiplier)
	if health != null:
		moa *= health.spread_multiplier()
	return deg_to_rad(moa / 60.0) * 0.5


## Dirección aleatoria dentro de un cono de semiángulo `angle` alrededor de `direction`.
static func spread_direction(direction: Vector3, angle: float, rng: RandomNumberGenerator) -> Vector3:
	var forward: Vector3 = direction.normalized()
	if angle <= 0.0:
		return forward
	var up: Vector3 = Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT
	var right: Vector3 = forward.cross(up).normalized()
	var true_up: Vector3 = right.cross(forward)
	# Distribución uniforme en el disco del cono.
	var r: float = tan(angle) * sqrt(rng.randf())
	var theta: float = rng.randf() * TAU
	return (forward + right * (r * cos(theta)) + true_up * (r * sin(theta))).normalized()
