class_name MovementComponent
extends Node
## Calcula la velocidad del jugador a partir de la entrada y la postura.
## No mueve el cuerpo: Player aplica el resultado con move_and_slide().

## Hook para la stamina (M5) y las heridas en las piernas: cuando sea false no se puede esprintar.
var sprint_allowed: bool = true
## Multiplicador de velocidad (heridas en las piernas; peso del inventario en M3).
var speed_multiplier: float = 1.0
## True si en el último cálculo el jugador estaba esprintando.
var is_sprinting: bool = false

var _profile: PlayerMovementProfile
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(profile: PlayerMovementProfile) -> void:
	_profile = profile


static func target_speed(profile: PlayerMovementProfile, posture: PostureComponent.Posture,
		sprinting: bool) -> float:
	match posture:
		PostureComponent.Posture.CROUCHING:
			return profile.crouch_speed
		PostureComponent.Posture.PRONE:
			return profile.prone_speed
	return profile.sprint_speed if sprinting else profile.walk_speed


## Solo se esprinta de pie, avanzando y sin asomarse.
func can_sprint(frame: PlayerInputFrame, posture: PostureComponent.Posture) -> bool:
	return (frame.sprint and sprint_allowed and posture == PostureComponent.Posture.STANDING
			and frame.move.y > 0.0 and frame.lean == 0)


## Nueva velocidad del cuerpo. `basis` es la orientación del cuerpo (define "adelante").
func compute_velocity(current: Vector3, frame: PlayerInputFrame, basis: Basis,
		posture: PostureComponent.Posture, on_floor: bool, posture_changed: bool,
		delta: float) -> Vector3:
	var velocity: Vector3 = current
	if not on_floor:
		velocity.y -= _gravity * delta

	is_sprinting = can_sprint(frame, posture)
	var wish: Vector3 = basis * Vector3(frame.move.x, 0.0, -frame.move.y)
	wish.y = 0.0
	var wish_dir: Vector3 = wish.normalized() * minf(frame.move.length(), 1.0)
	var target: Vector3 = wish_dir * target_speed(_profile, posture, is_sprinting) * speed_multiplier

	var accel: float = _profile.air_acceleration
	if on_floor:
		accel = _profile.acceleration if wish_dir != Vector3.ZERO else _profile.deceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(target.x, target.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if (frame.jump and on_floor and posture == PostureComponent.Posture.STANDING
			and not posture_changed):
		velocity.y = _profile.jump_velocity
	return velocity
