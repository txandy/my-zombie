@tool
extends BTAction
## Sin cobertura disponible: se agacha y pelea desde donde está.


func _tick(_delta: float) -> Status:
	var npc := agent as HumanNPC
	var target: Node3D = npc.perception.memory.target
	if target == null:
		return FAILURE
	npc.stop()
	npc.crouched = true
	if npc.perception.is_target_visible(target):
		npc.engage(target)
	else:
		npc.look_at_point(npc.perception.memory.last_known_position + Vector3.UP)
	return RUNNING
