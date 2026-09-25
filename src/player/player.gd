class_name Player
extends CharacterBody3D
## Controlador FPS del jugador. Orquesta los componentes; la lógica vive en cada uno.
##
## step() recibe un PlayerInputFrame en lugar de leer Input, para que en coop (M7)
## el host pueda simular el movimiento con los frames que envía el cliente.

@export var movement_profile: PlayerMovementProfile

@onready var _input: PlayerInput = $PlayerInput
@onready var _posture: PostureComponent = $Posture
@onready var _movement: MovementComponent = $Movement
@onready var _head: CameraRig = $Head


func _ready() -> void:
	assert(movement_profile != null, "Player necesita un PlayerMovementProfile")
	_posture.setup(self, $CollisionShape3D, _head, movement_profile)
	_movement.setup(movement_profile)
	_head.setup(movement_profile)


func _physics_process(delta: float) -> void:
	step(_input.poll(), delta)


## Simula un tick de movimiento con la entrada dada.
func step(frame: PlayerInputFrame, delta: float) -> void:
	_head.apply_look(self, frame.look_delta)
	_posture.update(frame, delta)
	velocity = _movement.compute_velocity(velocity, frame, global_basis, _posture.posture,
			is_on_floor(), _posture.changed_this_frame, delta)
	var can_lean: bool = (_posture.posture != PostureComponent.Posture.PRONE
			and not _movement.is_sprinting)
	_head.update_lean(frame.lean, can_lean, delta)
	move_and_slide()


func get_posture() -> PostureComponent.Posture:
	return _posture.posture


func is_sprinting() -> bool:
	return _movement.is_sprinting
