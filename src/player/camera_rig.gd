class_name CameraRig
extends Node3D
## Cabeza del jugador: pitch de la cámara, lean (desplazamiento lateral + roll), retroceso,
## temblor por dolor y zoom al apuntar. El yaw se aplica al cuerpo para que "adelante"
## siga a la mirada. Las balas salen en la dirección de la cámara, así que el retroceso
## y el temblor afectan a la puntería.

## Límite de pitch arriba/abajo. Es un límite de cámara, no de balance.
@export var pitch_limit_deg: float = 89.0
## Campo de visión normal y apuntando (ajustes de cámara, no de balance).
@export var fov: float = 80.0
@export var aim_fov: float = 60.0
@export var aim_fov_speed: float = 10.0
## 🔶 Amplitud (grados) y frecuencia (Hz) del temblor por dolor (GDD §5.1 no las fija).
@export var pain_sway_deg: float = 0.8
@export var pain_sway_hz: float = 0.6

var lean_amount: float = 0.0

var _pitch: float = 0.0
## Retroceso acumulado (x: pitch, y: yaw) en radianes; se recupera con el tiempo.
var _recoil := Vector2.ZERO
var _recoil_recovery: float = 0.0
var _sway_time: float = 0.0
var _profile: PlayerMovementProfile
var _rng := RandomNumberGenerator.new()

@onready var _camera: Camera3D = $Camera3D


func setup(profile: PlayerMovementProfile) -> void:
	_profile = profile
	_rng.randomize()


func camera() -> Camera3D:
	return _camera


func apply_look(body: Node3D, look_delta: Vector2) -> void:
	body.rotate_y(-look_delta.x)
	var limit: float = deg_to_rad(pitch_limit_deg)
	_pitch = clampf(_pitch - look_delta.y, -limit, limit)


## `direction`: -1 izquierda, 0 centro, 1 derecha. Si no está permitido, vuelve al centro.
func update_lean(direction: int, allowed: bool, delta: float) -> void:
	var target: float = float(direction) if allowed else 0.0
	lean_amount = move_toward(lean_amount, target, _profile.lean_speed * delta)
	_camera.position.x = lean_amount * _profile.lean_offset


## Retroceso de un disparo: sube la mira y la desvía a un lado al azar.
func add_recoil(weapon: WeaponDefinition) -> void:
	var side: float = _rng.randf_range(-1.0, 1.0)
	_recoil += Vector2(deg_to_rad(weapon.recoil_vertical_deg), deg_to_rad(weapon.recoil_horizontal_deg) * side)
	_recoil_recovery = weapon.recoil_recovery


## Aplica pitch, retroceso, temblor y FOV. Llamar una vez por tick tras el resto.
func update_view(aiming: bool, in_pain: bool, delta: float) -> void:
	_recoil = _recoil.move_toward(Vector2.ZERO, _recoil.length() * _recoil_recovery * delta + 0.0001)
	var sway := Vector2.ZERO
	if in_pain:
		_sway_time += delta
		var amplitude: float = deg_to_rad(pain_sway_deg)
		var phase: float = _sway_time * TAU * pain_sway_hz
		sway = Vector2(sin(phase) * amplitude, sin(phase * 0.7 + 1.3) * amplitude)
	rotation.x = _pitch + _recoil.x + sway.x
	_camera.rotation.y = _recoil.y + sway.y
	_camera.rotation.z = -lean_amount * deg_to_rad(_profile.lean_angle_deg)
	_camera.fov = move_toward(_camera.fov, aim_fov if aiming else fov, aim_fov_speed * 10.0 * delta)
