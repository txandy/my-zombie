class_name CameraRig
extends Node3D
## Cabeza del jugador: pitch de la cámara y lean (desplazamiento lateral + roll).
## El yaw se aplica al cuerpo para que "adelante" siga a la mirada.

## Límite de pitch arriba/abajo. Es un límite de cámara, no de balance.
@export var pitch_limit_deg: float = 89.0

var lean_amount: float = 0.0

var _pitch: float = 0.0
var _profile: PlayerMovementProfile

@onready var _camera: Camera3D = $Camera3D


func setup(profile: PlayerMovementProfile) -> void:
	_profile = profile


func apply_look(body: Node3D, look_delta: Vector2) -> void:
	body.rotate_y(-look_delta.x)
	var limit: float = deg_to_rad(pitch_limit_deg)
	_pitch = clampf(_pitch - look_delta.y, -limit, limit)
	rotation.x = _pitch


## `direction`: -1 izquierda, 0 centro, 1 derecha. Si no está permitido, vuelve al centro.
func update_lean(direction: int, allowed: bool, delta: float) -> void:
	var target: float = float(direction) if allowed else 0.0
	lean_amount = move_toward(lean_amount, target, _profile.lean_speed * delta)
	_camera.position.x = lean_amount * _profile.lean_offset
	_camera.rotation.z = -lean_amount * deg_to_rad(_profile.lean_angle_deg)
