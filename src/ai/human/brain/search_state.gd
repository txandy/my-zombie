extends LimboState
## Búsqueda (GDD §11.2): va a la última posición conocida y registra varios puntos
## alrededor; si no encuentra nada en search_time_s, vuelve a patrullar.

const SEARCH_RADIUS_M: float = 10.0

var _left: float = 0.0
var _points_left: int = 0


func _enter() -> void:
	var npc := agent as HumanNPC
	_left = npc.profile.search_time_s
	_points_left = 3
	npc.crouched = false
	npc.clear_look_target()
	npc.move_to(npc.perception.memory.last_known_position, true)


func _update(delta: float) -> void:
	var npc := agent as HumanNPC
	_left -= delta
	if _left <= 0.0:
		dispatch(EVENT_FINISHED)
		return
	if npc.is_moving() or _points_left <= 0:
		return
	_points_left -= 1
	var rng: RandomNumberGenerator = Ballistics.rng
	var around: Vector3 = npc.perception.memory.last_known_position
	var offset := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(4.0, SEARCH_RADIUS_M)
	npc.clear_look_target()
	npc.move_to(around + offset, false)
