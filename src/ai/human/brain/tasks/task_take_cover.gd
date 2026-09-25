@tool
extends BTAction
## Busca cobertura frente a la amenaza (utility scoring, papel en la escuadra) y corre a
## ella. Éxito al llegar. Falla si no hay ninguna (entonces pelea en campo abierto).

@export var reevaluate_s: float = 6.0


func _enter() -> void:
	var npc := agent as HumanNPC
	var threat: Vector3 = npc.perception.memory.last_known_position
	# Quien flanquea busca un ángulo distinto al del compañero que suprime.
	var flank_from: Variant = null
	if npc.squad != null and npc.squad.role_of(npc) == Squad.Role.FLANK:
		for member: HumanNPC in npc.squad.members():
			if member != npc:
				flank_from = member.global_position
				break
	var cover: CoverFinder.Cover = CoverFinder.find(npc, threat, flank_from)
	blackboard.set_var(&"cover", cover)
	blackboard.set_var(&"cover_time", 0.0)
	if cover != null:
		npc.crouched = false
		npc.move_to(cover.position, true)


func _tick(_delta: float) -> Status:
	var npc := agent as HumanNPC
	var cover: CoverFinder.Cover = blackboard.get_var(&"cover", null, false)
	if cover == null:
		return FAILURE
	# Mientras corre, dispara si tiene tiro (con más error, porque se mueve).
	var target: Node3D = npc.perception.memory.target
	if target != null and npc.perception.is_target_visible(target):
		npc.engage(target)
	return SUCCESS if npc.has_arrived() else RUNNING
