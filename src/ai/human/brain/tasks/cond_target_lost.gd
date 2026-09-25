@tool
extends BTCondition
## Éxito si hace más de `lost_after_s` que no ve a su objetivo (pasa a búsqueda).

@export var lost_after_s: float = 4.0


func _tick(delta: float) -> Status:
	var npc := agent as HumanNPC
	var target: Node3D = npc.perception.memory.target
	var seen: bool = target != null and npc.perception.is_target_visible(target)
	var lost: float = 0.0 if seen else float(blackboard.get_var(&"lost_time", 0.0, false)) + delta
	blackboard.set_var(&"lost_time", lost)
	return SUCCESS if lost >= lost_after_s or target == null else FAILURE
