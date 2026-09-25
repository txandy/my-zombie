@tool
extends BTCondition
## Éxito si está malherido y tiene con qué curarse (GDD §11.2: retirarse y curarse).


func _tick(_delta: float) -> Status:
	var npc := agent as HumanNPC
	return SUCCESS if npc.should_retreat() and not npc.used_all_medicine() else FAILURE
