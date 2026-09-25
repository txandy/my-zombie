class_name Viewmodel
extends Node3D
## Arma en primera persona (placeholder). Muestra el modelo del arma actual y un pequeño
## retroceso visual al disparar o golpear. Solo presentación.

## Hijos con el mismo nombre que el id del arma (assault_rifle, pistol, knife).
@export var kick_distance_m: float = 0.06
@export var kick_recovery: float = 12.0
@export var aim_offset := Vector3(-0.18, 0.05, 0.0)

var _rest: Vector3
var _kick: float = 0.0
var _aiming: bool = false


func _ready() -> void:
	_rest = position


func show_weapon(weapon: WeaponDefinition) -> void:
	for child: Node in get_children():
		(child as Node3D).visible = weapon != null and child.name == String(weapon.id)


func kick() -> void:
	_kick = 1.0


func set_aiming(aiming: bool) -> void:
	_aiming = aiming


func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, kick_recovery * delta)
	var target: Vector3 = _rest + (aim_offset if _aiming else Vector3.ZERO)
	position = position.lerp(target, minf(delta * 12.0, 1.0)) + Vector3(0, 0, kick_distance_m * _kick)
