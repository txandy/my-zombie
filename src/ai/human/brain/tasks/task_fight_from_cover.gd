@tool
extends BTAction
## Ciclo desde la cobertura: asomarse y disparar (o suprimir la última posición conocida)
## durante peek_time, y volver a cubrirse durante cover_time. Falla cuando conviene
## recolocarse (cobertura comprometida o demasiado tiempo en el mismo sitio).

@export var reposition_after_s: float = 14.0

var _phase_left: float = 0.0
var _peeking: bool = true
var _total: float = 0.0


func _enter() -> void:
	_peeking = true
	_phase_left = (agent as HumanNPC).profile.peek_time_s
	_total = 0.0


func _tick(delta: float) -> Status:
	var npc := agent as HumanNPC
	var cover: CoverFinder.Cover = blackboard.get_var(&"cover", null, false)
	_total += delta
	_phase_left -= delta
	if _phase_left <= 0.0:
		_peeking = not _peeking
		_phase_left = npc.profile.peek_time_s if _peeking else npc.profile.cover_time_s
	var hiding: bool = not _peeking and cover != null and cover.crouch
	npc.crouched = hiding
	var memory: Perception.Memory = npc.perception.memory
	if memory.target == null:
		return FAILURE
	if _peeking:
		if npc.perception.is_target_visible(memory.target):
			npc.engage(memory.target)
		elif npc.squad != null and npc.squad.role_of(npc) == Squad.Role.SUPPRESS:
			npc.suppress_fire(memory.last_known_position + Vector3.UP)
		else:
			npc.look_at_point(memory.last_known_position + Vector3.UP)
	else:
		npc.look_at_point(memory.last_known_position + Vector3.UP)
	# Cobertura comprometida: le ven y le disparan mientras se esconde, o lleva mucho aquí.
	if (hiding and npc.perception.suppression > 0.8) or _total > reposition_after_s:
		return FAILURE
	return RUNNING
