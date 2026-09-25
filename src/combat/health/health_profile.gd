class_name HealthProfile
extends Resource
## Salud por zonas y reglas de los estados (GDD §5.1). Valores en /data/combat/*.tres.
## Los HP por zona vienen del GDD; los parámetros de estados son placeholders 🔶 de tuning.

@export_group("HP por zona")
@export var head_hp: float = 0.0
@export var thorax_hp: float = 0.0
@export var stomach_hp: float = 0.0
@export var arm_hp: float = 0.0
@export var leg_hp: float = 0.0

@export_group("Redistribución")
## Fracción del daño sobrante de una zona destruida no vital que se reparte entre las demás.
@export var redistribution_factor: float = 0.0

@export_group("Sangrado")
## Probabilidad por punto de daño de causar sangrado leve / grave en la zona (limitada a 1).
@export var light_bleed_chance_per_damage: float = 0.0
@export var heavy_bleed_chance_per_damage: float = 0.0
## Daño por segundo en la zona sangrante.
@export var light_bleed_dps: float = 0.0
@export var heavy_bleed_dps: float = 0.0

@export_group("Fracturas y dolor")
## Probabilidad por punto de daño de fracturar una extremidad.
@export var fracture_chance_per_damage: float = 0.0
## Segundos de dolor (temblor de la mira) tras una fractura o una zona destruida.
@export var pain_duration_s: float = 0.0

@export_group("Penalizaciones")
## Multiplicador de la dispersión con un brazo destruido o fracturado.
@export var arm_injury_spread_multiplier: float = 1.0
## Multiplicador de la velocidad de recarga con un brazo destruido o fracturado.
@export var arm_injury_reload_multiplier: float = 1.0
## Multiplicador de la velocidad de movimiento con una pierna destruida o fracturada.
@export var leg_injury_speed_multiplier: float = 1.0


func max_hp(zone: BodyZones.Zone) -> float:
	if zone == BodyZones.Zone.HEAD:
		return head_hp
	if zone == BodyZones.Zone.THORAX:
		return thorax_hp
	if zone == BodyZones.Zone.STOMACH:
		return stomach_hp
	return arm_hp if BodyZones.is_arm(zone) else leg_hp
