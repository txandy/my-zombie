extends LimboState
## Retirada (GDD §11.2): corre a una cobertura alejada de la amenaza, se agacha y se
## cura con lo que lleve. Cuando termina (curado o sin medicinas), vuelve al combate.

var _heal_cooldown: float = 0.0


func _enter() -> void:
	var npc := agent as HumanNPC
	var cover: CoverFinder.Cover = CoverFinder.find(npc, npc.perception.memory.last_known_position, null, true)
	if cover != null:
		npc.crouched = false
		npc.move_to(cover.position, true)
	_heal_cooldown = 0.0


func _update(delta: float) -> void:
	var npc := agent as HumanNPC
	if npc.is_moving():
		return
	npc.crouched = true
	npc.look_at_point(npc.perception.memory.last_known_position + Vector3.UP)
	_heal_cooldown -= delta
	if _heal_cooldown > 0.0:
		return
	_heal_cooldown = 1.5
	if not npc.use_best_medicine():
		dispatch(EVENT_FINISHED)
