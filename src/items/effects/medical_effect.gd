class_name MedicalEffect
extends ItemUseEffect
## Efecto médico sobre el HealthComponent del usuario (GDD §5.1): vendas, torniquete,
## férula y analgésicos. Se aplica en el host.

enum Treatment { STOP_LIGHT_BLEED, STOP_HEAVY_BLEED, FIX_FRACTURE, PAINKILLER, CURE_INFECTION }

@export var treatment: Treatment = Treatment.STOP_LIGHT_BLEED
## Solo analgésicos: segundos de efecto.
@export var duration_s: float = 0.0


func can_apply(user: Node) -> bool:
	var health: HealthComponent = _health_of(user)
	if health == null or health.is_dead:
		return false
	match treatment:
		Treatment.STOP_LIGHT_BLEED:
			return health.has_bleeding(HealthComponent.Bleed.LIGHT)
		Treatment.STOP_HEAVY_BLEED:
			return health.has_bleeding(HealthComponent.Bleed.HEAVY)
		Treatment.FIX_FRACTURE:
			return health.has_fracture()
		Treatment.CURE_INFECTION:
			return health.infected
	return true


func apply(user: Node) -> bool:
	var health: HealthComponent = _health_of(user)
	if not can_apply(user):
		return false
	match treatment:
		Treatment.STOP_LIGHT_BLEED:
			return health.stop_bleeding(HealthComponent.Bleed.LIGHT)
		Treatment.STOP_HEAVY_BLEED:
			return health.stop_bleeding(HealthComponent.Bleed.HEAVY)
		Treatment.FIX_FRACTURE:
			return health.fix_fracture()
		Treatment.CURE_INFECTION:
			return health.cure_infection()
	health.suppress_pain(duration_s)
	return true


static func _health_of(user: Node) -> HealthComponent:
	return user.get_node_or_null(^"Health") as HealthComponent if user != null else null
