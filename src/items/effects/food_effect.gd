class_name FoodEffect
extends ItemUseEffect
## Comida o bebida (GDD §5.1): recupera hambre y/o sed del SurvivalComponent del usuario.

@export var hunger: float = 0.0
@export var thirst: float = 0.0


func can_apply(user: Node) -> bool:
	var survival: SurvivalComponent = _survival_of(user)
	if survival == null:
		return false
	return (hunger > 0.0 and survival.is_hungry()) or (thirst > 0.0 and survival.is_thirsty())


func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	_survival_of(user).eat(hunger, thirst)
	return true


static func _survival_of(user: Node) -> SurvivalComponent:
	return user.get_node_or_null(^"Survival") as SurvivalComponent if user != null else null
