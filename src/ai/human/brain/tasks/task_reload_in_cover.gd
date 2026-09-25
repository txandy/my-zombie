@tool
extends BTAction
## Recarga (agachado si está a cubierto) cuando le quedan pocas balas. Falla si no hace falta.


func _tick(_delta: float) -> Status:
	var npc := agent as HumanNPC
	if npc.weapons.is_reloading():
		return RUNNING
	if not npc.needs_reload():
		return FAILURE
	var cover: CoverFinder.Cover = blackboard.get_var(&"cover", null, false)
	npc.crouched = cover != null and cover.crouch
	npc.reload()
	return RUNNING
