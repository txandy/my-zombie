class_name PostureComponent
extends Node
## Postura del jugador (de pie, agachado, tumbado): altura de la cápsula y de la cámara.
## No deja levantarse si no hay espacio por encima.

signal posture_changed(posture: Posture)

enum Posture { STANDING, CROUCHING, PRONE }

var posture: Posture = Posture.STANDING
## True si la postura ha cambiado en el último update() (el salto que la provoca no salta).
var changed_this_frame: bool = false
## Altura actual de la cápsula, interpolada hacia la de la postura.
var current_height: float = 0.0

var _body: CharacterBody3D
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _head: Node3D
var _profile: PlayerMovementProfile


func setup(body: CharacterBody3D, collision: CollisionShape3D, head: Node3D,
		profile: PlayerMovementProfile) -> void:
	_body = body
	_collision = collision
	_capsule = collision.shape as CapsuleShape3D
	_head = head
	_profile = profile
	_capsule.radius = profile.capsule_radius
	current_height = height_for(profile, posture)
	_apply_height()


## Postura pedida por la entrada, sin tener en cuenta el espacio disponible.
static func resolve_request(current: Posture, frame: PlayerInputFrame) -> Posture:
	if frame.prone_toggled:
		return Posture.STANDING if current == Posture.PRONE else Posture.PRONE
	if frame.crouch_toggled:
		return Posture.STANDING if current == Posture.CROUCHING else Posture.CROUCHING
	if frame.jump:
		match current:
			Posture.PRONE:
				return Posture.CROUCHING
			Posture.CROUCHING:
				return Posture.STANDING
	return current


static func height_for(profile: PlayerMovementProfile, target: Posture) -> float:
	match target:
		Posture.CROUCHING:
			return profile.crouch_height
		Posture.PRONE:
			return profile.prone_height
	return profile.standing_height


func update(frame: PlayerInputFrame, delta: float) -> void:
	changed_this_frame = false
	var wanted: Posture = resolve_request(posture, frame)
	if wanted != posture and _can_fit(height_for(_profile, wanted)):
		posture = wanted
		changed_this_frame = true
		posture_changed.emit(posture)
	current_height = move_toward(current_height, height_for(_profile, posture),
			_profile.posture_change_speed * delta)
	_apply_height()


func _apply_height() -> void:
	var height: float = maxf(current_height, _capsule.radius * 2.0)
	_capsule.height = height
	_collision.position.y = height * 0.5
	_head.position.y = current_height - _profile.eye_offset


# Comprueba si una cápsula de `height` cabe en la posición actual del cuerpo.
func _can_fit(height: float) -> bool:
	if height <= current_height:
		return true
	var shape := CapsuleShape3D.new()
	shape.radius = _capsule.radius
	shape.height = maxf(height, shape.radius * 2.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	# Se eleva un poco para no detectar el suelo sobre el que está apoyado.
	var lift: float = 0.05
	params.transform = Transform3D(Basis.IDENTITY,
			_body.global_position + Vector3.UP * (shape.height * 0.5 + lift))
	params.collision_mask = _body.collision_mask
	params.exclude = [_body.get_rid()]
	return _body.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()
