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
## Peer dueño de este jugador (1 = host). Lo fija quien lo crea antes de añadirlo al árbol.
var peer_id: int = 1

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
@onready var build_tool: BuildTool = $BuildTool
@onready var _viewmodel: Viewmodel = $Head/Camera3D/Viewmodel
@onready var net: PlayerNet = $PlayerNet


func _ready() -> void:
	assert(movement_profile != null, "Player necesita un PlayerMovementProfile")
	collision_layer = PhysicsLayers.CHARACTERS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CHARACTERS
	add_to_group(&"player")
	inventory.owner_peer_id = peer_id
	weapons.owner_peer_id = peer_id
	if not is_local():
		_become_remote()
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
	net.setup(self)


func _physics_process(delta: float) -> void:
	if is_local():
		step(_input.poll(), delta)
		net.publish_local()
		return
	net.apply_remote()
	if multiplayer.is_server():
		net.server_tick(delta)


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
	if build_tool.active:
		if frame.fire_pressed:
			build_tool.place()
		return
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


func _on_shot_fired(_weapon: WeaponDefinition) -> void:
	if is_local():
		play_shot_feedback()


## Retroceso y animación del disparo (en el dueño; en un cliente llega del host).
func play_shot_feedback() -> void:
	var weapon: WeaponDefinition = weapons.current()
	if weapon != null:
		_head.add_recoil(weapon)
	_viewmodel.kick()


func _on_died(_zone: BodyZones.Zone) -> void:
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(respawn_time_s).timeout
	net.teleport(spawn_point)
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


# --- Red ---

## True si este jugador lo controla este peer.
func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func head_pitch() -> float:
	return _head.rotation.x


## ¿Pisa suelo? (en jugadores remotos lo dice su dueño).
func is_grounded() -> bool:
	return is_on_floor() if is_local() else net.net_on_floor


## Postura y mirada de un jugador remoto (para las hitboxes, la IA y lo que ven los demás).
func apply_net_posture(posture: int, pitch: float) -> void:
	_posture.posture = posture as PostureComponent.Posture
	_posture.current_height = PostureComponent.height_for(movement_profile, _posture.posture)
	_hitboxes.scale.y = _posture.current_height / movement_profile.standing_height
	_head.rotation.x = pitch


# Un jugador que no es de este peer: sin cámara, sin HUD, sin entrada local.
func _become_remote() -> void:
	_head.camera().current = false
	_viewmodel.visible = false
	for node: Node in [$HUD, _input, build_tool]:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	($HUD as CanvasLayer).visible = false
	interactor.set_physics_process(false)
