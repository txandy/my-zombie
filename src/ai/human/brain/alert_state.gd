extends LimboState
## Alerta: ha oído algo. Mira hacia allí y se acerca con cuidado un trecho (o se agacha
## si está cerca). Si no ve nada en `alert_time_s`, vuelve a patrullar.

@export var alert_time_s: float = 12.0

var _left: float = 0.0


func _enter() -> void:
	var npc := agent as HumanNPC
	_left = alert_time_s
	var noise: Vector3 = npc.perception.memory.last_known_position
	npc.look_at_point(noise + Vector3.UP)
	var to_noise: Vector3 = noise - npc.global_position
	if to_noise.length() > 10.0:
		npc.move_to(npc.global_position + to_noise * 0.4, false)
	else:
		npc.stop()
		npc.crouched = true


func _update(delta: float) -> void:
	var npc := agent as HumanNPC
	npc.look_at_point(npc.perception.memory.last_known_position + Vector3.UP)
	_left -= delta
	if _left <= 0.0:
		dispatch(EVENT_FINISHED)


func _exit() -> void:
	(agent as HumanNPC).crouched = false
