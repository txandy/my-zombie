class_name HumanNPC
extends CharacterBody3D
## NPC humano (GDD §11.2). Usa los mismos componentes de combate que el jugador
## (salud, armadura, hitboxes, WeaponHolder, inventario) y expone acciones de bajo nivel
## (moverse, mirar, agacharse, disparar, recargar, curarse) que usa su cerebro LimboAI.
## Toda su lógica corre en el host.

signal died()

@export var profile: NPCCombatProfile
@export var loadout: NPCLoadout
## Grupo de facción (los jugadores y otras facciones hostiles son objetivos).
@export var faction: StringName = &"bandits"

## Posición de origen (patrulla alrededor de ella).
var home_position: Vector3
## Escuadra a la que pertenece (o null).
var squad: Squad
var aim_model: AimModel
## Si está agachado (tras cobertura baja).
var crouched: bool = false
## Lo decide el host y se replica: al morir, todos los peers ven el cadáver.
var is_dead: bool = false:
	set(value):
		is_dead = value
		if value and is_node_ready():
			_show_corpse()
## Nivel de detalle de la IA (lo fija AIManager): 0 completo, 1 simplificado, 2 congelado.
var lod_level: int = 0
var corpse_container: ItemContainer
var brain: HumanBrain

var _move_target: Vector3
var _moving: bool = false
var _running: bool = false
var _look_target: Vector3
var _has_look_target: bool = false
var _burst_left: int = 0
var _next_shot_s: float = 0.0
var _time_s: float = 0.0
var _aim_zone: BodyZones.Zone = BodyZones.Zone.THORAX
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _brain_accumulator: float = 0.0

const EYE_HEIGHT_M: float = 1.6

@onready var health: HealthComponent = $Health
@onready var armor: ArmorComponent = $Armor
@onready var weapons: WeaponHolder = $WeaponHolder
@onready var inventory: InventoryComponent = $Inventory
@onready var perception: Perception = $Perception
@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var eye: Node3D = $Eye
@onready var _hitboxes: Node3D = $Hitboxes
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"npc")
	add_to_group(faction)
	NetSync.add(self, [":position", ":rotation", ":crouched", ":is_dead"], 1, true, 0.05)
	collision_layer = PhysicsLayers.CHARACTERS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CHARACTERS
	home_position = global_position
	aim_model = AimModel.new(profile)
	weapons.ammo_provider = inventory
	inventory.inventory_changed.connect(_sync_equipment)
	health.died.connect(_on_died)
	perception.target_spotted.connect(_on_target_spotted)
	if multiplayer.is_server():
		var rng: RandomNumberGenerator = SeedUtil.make_rng(GameState.world_seed, StringName("npc:%s" % name))
		inventory.apply_loadout(loadout, rng)
	_sync_equipment()
	# Solo el host piensa por los NPCs (en los clientes son marionetas sincronizadas).
	if multiplayer.is_server():
		brain = HumanBrain.new()
		brain.name = "Brain"
		add_child(brain)
		brain.setup(self)


func _physics_process(delta: float) -> void:
	if is_dead or not multiplayer.is_server() or lod_level >= 2:
		return
	_time_s += delta
	_update_movement(delta)
	_update_facing(delta)
	var target: Node3D = perception.memory.target
	aim_model.update(delta, target != null and perception.is_target_visible(target))
	_hitboxes.scale.y = 0.65 if crouched else 1.0
	_visual.scale.y = _hitboxes.scale.y
	# Los ojos bajan al agacharse: escondido tras una cobertura baja no ve (ni es visto).
	eye.position.y = EYE_HEIGHT_M * _hitboxes.scale.y
	_brain_tick(delta)


# --- Movimiento ---

## Va hacia `point` por la malla de navegación (o en línea recta si no hay malla).
func move_to(point: Vector3, run: bool) -> void:
	_move_target = point
	_moving = true
	_running = run
	nav.target_position = point


func stop() -> void:
	_moving = false
	velocity.x = 0.0
	velocity.z = 0.0


func is_moving() -> bool:
	return _moving


func has_arrived(tolerance_m: float = 0.8) -> bool:
	return not _moving or _flat_distance(global_position, _move_target) <= tolerance_m


func _update_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _moving and has_arrived(0.5):
		stop()
	var horizontal := Vector3.ZERO
	if _moving:
		var next: Vector3 = _next_path_point()
		var dir: Vector3 = next - global_position
		dir.y = 0.0
		var speed: float = (profile.run_speed if _running else profile.walk_speed) * health.movement_multiplier()
		if crouched:
			speed *= 0.5
		horizontal = dir.normalized() * speed if dir.length() > 0.05 else Vector3.ZERO
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _next_path_point() -> Vector3:
	var map: RID = nav.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 and not nav.is_navigation_finished():
		var point: Vector3 = nav.get_next_path_position()
		if _flat_distance(point, global_position) > 0.05:
			return point
	return _move_target


# --- Mirar y apuntar ---

func look_at_point(point: Vector3) -> void:
	_look_target = point
	_has_look_target = true


func clear_look_target() -> void:
	_has_look_target = false


func _update_facing(delta: float) -> void:
	var target_point: Vector3 = _look_target
	if not _has_look_target and _moving:
		target_point = _move_target
	elif not _has_look_target:
		return
	var to_target: Vector3 = target_point - global_position
	to_target.y = 0.0
	if to_target.length() < 0.1:
		return
	var desired: float = atan2(-to_target.x, -to_target.z)
	rotation.y = rotate_toward(rotation.y, desired, deg_to_rad(profile.turn_speed_deg) * delta)
	var to_eye: Vector3 = target_point - eye.global_position
	eye.rotation.x = atan2(to_eye.y, Vector2(to_eye.x, to_eye.z).length())


## Grados entre hacia donde mira y el punto.
func facing_error_deg(point: Vector3) -> float:
	var to_point: Vector3 = point - eye.global_position
	return rad_to_deg((-eye.global_basis.z).angle_to(to_point))


# --- Combate ---

## Apunta y dispara a `target` siguiendo el modelo de puntería. Devuelve true si ha disparado.
func engage(target: Node3D) -> bool:
	var aim_point: Vector3 = _aim_point(target)
	look_at_point(aim_point)
	if not aim_model.can_fire() or not perception.is_target_visible(target):
		return false
	if facing_error_deg(aim_point) > 12.0 or _time_s < _next_shot_s:
		return false
	var weapon: WeaponDefinition = weapons.current()
	if weapon == null or weapon.kind != WeaponDefinition.Kind.FIREARM:
		return false
	if weapons.current_rounds() <= 0:
		weapons.request_reload()
		return false
	if _burst_left <= 0:
		_burst_left = Ballistics.rng.randi_range(profile.burst_min, profile.burst_max) if weapon.fire_mode == WeaponDefinition.FireMode.AUTO else 1
		_aim_zone = aim_model.pick_zone(Ballistics.rng)
	var direction: Vector3 = aim_model.aim_direction(eye.global_position, aim_point, _aim_context(target), Ballistics.rng)
	weapons.request_attack(eye.global_position, direction, aim_model.settle > 0.5)
	_burst_left -= 1
	if weapon.fire_mode == WeaponDefinition.FireMode.AUTO:
		_next_shot_s = _time_s + (weapon.fire_interval_s() if _burst_left > 0 else profile.burst_pause_s)
	else:
		_next_shot_s = _time_s + maxf(profile.semi_interval_s, weapon.fire_interval_s())
	return true


func _aim_point(target: Node3D) -> Vector3:
	var point: Vector3 = target.global_position + Vector3.UP * 1.3
	var hitboxes: Node = target.get_node_or_null(^"Hitboxes")
	if hitboxes != null:
		for child: Node in hitboxes.get_children():
			if (child as Hitbox).zone == _aim_zone:
				point = (child as Node3D).global_position
	var target_velocity: Vector3 = (target as CharacterBody3D).velocity if target is CharacterBody3D else Vector3.ZERO
	var muzzle: float = weapons.loaded_ammo().muzzle_velocity_mps if weapons.loaded_ammo() != null else 0.0
	return aim_model.lead_point(point, target_velocity, eye.global_position.distance_to(point), muzzle)


func _aim_context(target: Node3D) -> AimModel.Context:
	var context := AimModel.Context.new()
	var to_target: Vector3 = target.global_position - global_position
	context.distance_m = to_target.length()
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		context.target_lateral_speed = (v - to_target.normalized() * v.dot(to_target.normalized())).length()
	context.self_moving = Vector2(velocity.x, velocity.z).length() > 0.5
	context.suppression = perception.suppression
	context.injury_multiplier = health.spread_multiplier()
	return context


func needs_reload() -> bool:
	var weapon: WeaponDefinition = weapons.current()
	return weapon != null and weapon.kind == WeaponDefinition.Kind.FIREARM \
			and weapons.current_rounds() < ceili(weapon.magazine_size * 0.3) and weapons.reserve_ammo() != 0


func reload() -> void:
	weapons.request_reload()


## Usa una medicina útil ahora (torniquete > venda > férula > analgésico). True si ha usado algo.
func use_best_medicine() -> bool:
	var order: Array[MedicalEffect.Treatment] = [MedicalEffect.Treatment.STOP_HEAVY_BLEED,
			MedicalEffect.Treatment.STOP_LIGHT_BLEED, MedicalEffect.Treatment.FIX_FRACTURE,
			MedicalEffect.Treatment.PAINKILLER]
	for treatment: MedicalEffect.Treatment in order:
		var item: ItemInstance = _find_medicine(treatment)
		if item != null and item.definition.use_effect.can_apply(self):
			inventory.request_use(item.uuid)
			return true
	return false


func _find_medicine(treatment: MedicalEffect.Treatment) -> ItemInstance:
	for container: ItemContainer in inventory.inventory.storage():
		for item: ItemInstance in container.items():
			var effect := item.definition.use_effect as MedicalEffect
			if effect != null and effect.treatment == treatment:
				return item
	return null


func should_retreat() -> bool:
	var thorax: float = health.hp(BodyZones.Zone.THORAX) / health.profile.max_hp(BodyZones.Zone.THORAX)
	return thorax < profile.retreat_health_fraction or health.has_bleeding(HealthComponent.Bleed.HEAVY)


func get_posture() -> PostureComponent.Posture:
	return PostureComponent.Posture.CROUCHING if crouched else PostureComponent.Posture.STANDING


func is_sprinting() -> bool:
	return _running and _moving


func _on_target_spotted(_target: Node3D) -> void:
	aim_model.on_target_acquired(Ballistics.rng)
	if squad != null:
		squad.share_contact(self, perception.memory)


# --- Equipo y muerte ---

func _sync_equipment() -> void:
	var inv: Inventory = inventory.inventory
	weapons.set_weapon_items([inv.item_in(Inventory.Slot.PRIMARY), inv.item_in(Inventory.Slot.SECONDARY),
			inv.item_in(Inventory.Slot.PISTOL), inv.item_in(Inventory.Slot.MELEE)])
	armor.set_from_items([inv.item_in(Inventory.Slot.HELMET), inv.item_in(Inventory.Slot.TORSO)])


func _on_died(_zone: BodyZones.Zone) -> void:
	is_dead = true
	stop()
	brain.stop()
	_become_corpse()
	died.emit()


# El cadáver guarda todo lo que llevaba (equipado y guardado) en un contenedor saqueable.
func _become_corpse() -> void:
	corpse_container = ItemContainer.new(StringName("corpse_%d" % get_instance_id()), [Vector2i(10, 8)])
	var inv: Inventory = inventory.inventory
	for slot: Inventory.Slot in inv.equipped.keys():
		var item: ItemInstance = inv.item_in(slot)
		inv.detach(item)
		corpse_container.insert_anywhere(item)
	for item: ItemInstance in inv.pockets.items():
		inv.pockets.remove(item)
		corpse_container.insert_anywhere(item)
	crouched = false


func interaction_text() -> String:
	return "Registrar cadáver" if is_dead else ""


func interact(player: Player) -> void:
	if is_dead:
		player.inventory.open_external(corpse_container, self, "cadáver")


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Fuego de supresión a un punto (última posición conocida) aunque no vea al objetivo:
## más disperso y a ráfagas cortas. Lo usa el miembro de la escuadra que suprime.
func suppress_fire(point: Vector3) -> bool:
	look_at_point(point)
	var weapon: WeaponDefinition = weapons.current()
	if weapon == null or weapon.kind != WeaponDefinition.Kind.FIREARM or _time_s < _next_shot_s:
		return false
	if facing_error_deg(point) > 12.0 or not aim_model.can_fire():
		return false
	if weapons.current_rounds() <= 0:
		weapons.request_reload()
		return false
	var spread: float = deg_to_rad(profile.base_spread_deg * 1.5)
	weapons.request_attack(eye.global_position, WeaponHolder.spread_direction(point - eye.global_position, spread, Ballistics.rng), false)
	_next_shot_s = _time_s + profile.burst_pause_s * 1.5
	return true


## True si no le queda ninguna medicina útil para su estado actual.
func used_all_medicine() -> bool:
	for container: ItemContainer in inventory.inventory.storage():
		for item: ItemInstance in container.items():
			var effect := item.definition.use_effect as MedicalEffect
			if effect != null and effect.can_apply(self):
				return false
	return true


# LOD 0: el cerebro piensa cada tick. LOD 1 (lejos): 4 veces por segundo.
func _brain_tick(delta: float) -> void:
	_brain_accumulator += delta
	var interval: float = 0.0 if lod_level == 0 else 0.25
	if _brain_accumulator >= interval:
		brain.update(_brain_accumulator)
		_brain_accumulator = 0.0


# --- Guardado (GDD §13: NPCs persistentes) ---

func to_save() -> Dictionary:
	var data: Dictionary = {"dead": is_dead, "pos": global_position, "rot": rotation.y,
			"home": home_position, "health": health.to_save()}
	if is_dead:
		data["corpse"] = ItemSerializer.container_to_list(corpse_container)
	else:
		data["inventory"] = ItemSerializer.inventory_to_dict(inventory)
	return data


func from_save(data: Dictionary, catalog: ItemCatalog) -> void:
	global_position = data.pos
	rotation.y = float(data.rot)
	home_position = data.home
	if bool(data.dead):
		health.from_save(data.health)
		is_dead = true
		stop()
		brain.stop()
		_become_corpse()
		for item: ItemInstance in corpse_container.items():
			corpse_container.remove(item)
		ItemSerializer.container_from_list(corpse_container, data.corpse, catalog)
		return
	health.from_save(data.health)
	ItemSerializer.inventory_from_dict(inventory, data.inventory, catalog)


func _show_corpse() -> void:
	collision_layer = PhysicsLayers.INTERACTABLES
	_visual.rotation.x = -PI * 0.5
	_visual.position.y = 0.2
