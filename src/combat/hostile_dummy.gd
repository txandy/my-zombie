extends Node
## Tirador de pruebas para la escena de tiro: dispara al jugador con su WeaponHolder
## (el mismo sistema que el jugador) cuando lo ve. No es IA: solo sirve para recibir daño.
## Apunta al tórax con un error aleatorio para que no acierte siempre.

@export var weapons: WeaponHolder
@export var dummy: TargetDummy
@export var interval_s: float = 1.5
@export var max_range_m: float = 40.0
## Radio del error de puntería en el objetivo (m).
@export var aim_error_m: float = 0.35

var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or dummy.health.is_dead:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval_s
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health.is_dead:
		return
	var eye: Vector3 = dummy.global_position + Vector3(0, 1.55, 0)
	var target: Vector3 = player.global_position + Vector3(0, 1.3, 0)
	if eye.distance_to(target) > max_range_m or not _can_see(eye, target):
		return
	var error := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * aim_error_m
	weapons.request_attack(eye, (target + error - eye).normalized(), false)
	if weapons.current_rounds() == 0:
		weapons.request_reload()


func _can_see(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	return dummy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
