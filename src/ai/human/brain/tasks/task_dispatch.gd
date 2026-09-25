@tool
extends BTAction
## Envía un evento a la máquina de estados del NPC (p. ej. "retreat", "target_lost").

@export var event: StringName = &""


func _tick(_delta: float) -> Status:
	(agent as HumanNPC).brain.dispatch(event)
	return SUCCESS
