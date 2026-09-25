class_name Player
extends CharacterBody3D
## Controlador FPS del jugador. Orquesta los componentes; la lógica vive en cada uno.
##
## step() recibe un PlayerInputFrame en lugar de leer Input, para que en coop (M7)
## el host pueda simular el movimiento con los frames que envía el cliente.

@export var movement_profile: PlayerMovementProfile
## 🔶 Reaparición de desarrollo tras morir (no hay diseño de muerte/respawn todavía).
@export var respawn_time_s: float = 3.0
## Equipo con el que aparece (lo reparte el host).
@export var starting_kit: StartingKit

var spawn_point: Vector3 = Vector3.ZERO

@onready var _input: PlayerInput = $PlayerInput
@onready var _posture: PostureComponent = $Posture
@onready var _movement: MovementComponent = $Movement
@onready var _head: CameraRig = $Head
@onready var _hitboxes: Node3D = $Hitboxes
@onready var health: HealthComponent = $Health
@onready var armor: ArmorComponent = $Armor
@onready var weapons: WeaponHolder = $WeaponHolder
@onready var inventory: InventoryComponent = $Inventory
@onready var interactor: Interactor = $Interactor
@onready var survival: SurvivalComponent = $Survival
@onready var _viewmodel: Viewmodel = $Head/Camera3D/Viewmodel


func _ready() -> void:
	assert(movement_profile != null, "Player necesita un PlayerMovementProfile")
	collision_layer = PhysicsLayers.CHARACTERS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CHARACTERS
	add_to_group(&"player")
	_posture.setup(self, $CollisionShape3D, _head, movement_profile)
	_movement.setup(movement_profile)
	_head.setup(movement_profile)
	spawn_point = global_position
	weapons.shot_fired.connect(_on_shot_fired)
	weapons.melee_swung.connect(func(_w: WeaponDefinition) -> void: _viewmodel.kick())
	weapons.weapon_changed.connect(_viewmodel.show_weapon)
	health.died.connect(_on_died)
	weapons.ammo_provider = inventory
	inventory.inventory_changed.connect(_sync_equipment)
	inventory.item_dropped.connect(_on_item_dropped)
	inventory.apply_kit(starting_kit)
	_sync_equipment()
	_viewmodel.show_weapon(weapons.current())


func _physics_process(delta: float) -> void:
	step(_input.poll(), delta)


## Simula un tick de movimiento y combate con la entrada dada.
func step(frame: PlayerInputFrame, delta: float) -> void:
	if health.is_dead:
		frame = PlayerInputFrame.new()
	_head.apply_look(self, frame.look_delta)
	_posture.update(frame, delta)
	_movement.sprint_allowed = health.can_sprint() and survival.can_sprint()
	_movement.jump_allowed = survival.can_jump()
	_movement.speed_multiplier = health.movement_multiplier() * inventory.inventory.speed_multiplier()
	# El peso encarece la stamina en la misma proporción en que frena (GDD §7.2).
	survival.stamina_cost_multiplier = 1.0 / maxf(inventory.inventory.speed_multiplier(), 0.1)
	velocity = _movement.compute_velocity(velocity, frame, global_basis, _posture.posture,
			is_on_floor(), _posture.changed_this_frame, delta)
	var can_lean: bool = (_posture.posture != PostureComponent.Posture.PRONE
			and not _movement.is_sprinting)
	_head.update_lean(frame.lean, can_lean, delta)
	_head.update_view(frame.aim, health.has_pain(), delta)
	_viewmodel.set_aiming(frame.aim)
	# Las hitboxes siguen la altura de la postura (aproximación hasta tener esqueleto).
	_hitboxes.scale.y = _posture.current_height / movement_profile.standing_height
	_spend_stamina(frame, delta)
	move_and_slide()
	_handle_weapons(frame)
	if frame.interact:
		interactor.request_interact()
	if frame.quick_use > 0:
		inventory.request_use_quick(frame.quick_use)


func _handle_weapons(frame: PlayerInputFrame) -> void:
	if frame.weapon_slot >= 0:
		weapons.request_switch(frame.weapon_slot)
	if frame.reload:
		weapons.request_reload()
	var weapon: WeaponDefinition = weapons.current()
	if weapon == null or _movement.is_sprinting:
		return
	var automatic: bool = (weapon.kind == WeaponDefinition.Kind.FIREARM
			and weapon.fire_mode == WeaponDefinition.FireMode.AUTO)
	if frame.fire_held if automatic else frame.fire_pressed:
		var cam: Camera3D = _head.camera()
		weapons.request_attack(cam.global_position, -cam.global_basis.z, frame.aim)


func _on_shot_fired(weapon: WeaponDefinition) -> void:
	_head.add_recoil(weapon)
	_viewmodel.kick()


func _on_died(_zone: BodyZones.Zone) -> void:
	await get_tree().create_timer(respawn_time_s).timeout
	global_position = spawn_point
	velocity = Vector3.ZERO
	health.reset()
	survival.reset()
	_sync_equipment()


func get_posture() -> PostureComponent.Posture:
	return _posture.posture


func is_sprinting() -> bool:
	return _movement.is_sprinting


## El equipo del inventario manda: armas en los slots de arma y armadura en casco/torso.
func _sync_equipment() -> void:
	var inv: Inventory = inventory.inventory
	weapons.set_weapon_items([inv.item_in(Inventory.Slot.PRIMARY), inv.item_in(Inventory.Slot.SECONDARY),
			inv.item_in(Inventory.Slot.PISTOL), inv.item_in(Inventory.Slot.MELEE)])
	armor.set_from_items([inv.item_in(Inventory.Slot.HELMET), inv.item_in(Inventory.Slot.TORSO)])


func camera() -> Camera3D:
	return _head.camera()


## Host: un objeto tirado aparece delante del jugador.
func _on_item_dropped(item: ItemInstance) -> void:
	var spot: Vector3 = global_position + Vector3.UP * 0.8 - global_basis.z * 0.7
	WorldItem.spawn(item, spot, get_parent())


func _spend_stamina(frame: PlayerInputFrame, delta: float) -> void:
	if _movement.is_sprinting:
		survival.drain_sprint(delta)
	if _movement.did_jump:
		survival.on_jump()
	var weapon: WeaponDefinition = weapons.current()
	if frame.aim and weapon != null and weapon.kind == WeaponDefinition.Kind.FIREARM:
		survival.drain_aim(delta)
