class_name FootstepEmitter
extends Node
## Emite pasos audibles para la IA según la postura y la velocidad (GDD §5.2).
## Cuenta la distancia recorrida en el suelo y emite un sonido cada `step_distance_m`.
## 🔶 El tipo de superficie aún no influye.

@export var rules: PerceptionRules
@export var body: CharacterBody3D

var _travelled_m: float = 0.0
var _last_position: Vector3


func _ready() -> void:
	_last_position = body.global_position


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var position: Vector3 = body.global_position
	var moved: float = Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not body.is_on_floor() or moved > 5.0:
		return
	_travelled_m += moved
	if _travelled_m >= rules.step_distance_m:
		_travelled_m = 0.0
		EventBus.sound_emitted.emit(position, step_radius(), &"footstep", body)


## Radio del paso según lo que hace el cuerpo ahora.
func step_radius() -> float:
	if body.has_method(&"get_posture"):
		match int(body.call(&"get_posture")):
			PostureComponent.Posture.CROUCHING:
				return rules.crouch_step_radius_m
			PostureComponent.Posture.PRONE:
				return rules.prone_step_radius_m
	if body.has_method(&"is_sprinting") and bool(body.call(&"is_sprinting")):
		return rules.sprint_step_radius_m
	return rules.walk_step_radius_m
