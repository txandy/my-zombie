extends LimboState
## Patrulla: pasea entre puntos al azar alrededor de su posición de origen y se para un rato.

const PATROL_RADIUS_M: float = 12.0

var _wait_left: float = 0.0
var _heal_cooldown: float = 0.0


func _enter() -> void:
	var npc := agent as HumanNPC
	npc.crouched = false
	npc.clear_look_target()
	# Al empezar vigila un rato donde está antes de echar a andar.
	_wait_left = Ballistics.rng.randf_range(2.0, 5.0)
	_heal_cooldown = 0.0


func _update(delta: float) -> void:
	var npc := agent as HumanNPC
	# Fuera de combate también se cura si está herido.
	_heal_cooldown -= delta
	if _heal_cooldown <= 0.0 and npc.should_retreat() and not npc.used_all_medicine():
		_heal_cooldown = 1.5
		npc.use_best_medicine()
	if npc.is_moving():
		return
	_wait_left -= delta
	if _wait_left > 0.0:
		return
	var rng: RandomNumberGenerator = Ballistics.rng
	var offset := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(3.0, PATROL_RADIUS_M)
	npc.clear_look_target()
	npc.move_to(npc.home_position + offset, false)
	_wait_left = rng.randf_range(2.0, 5.0)
