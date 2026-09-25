class_name SurvivalProfile
extends Resource
## Parámetros de supervivencia (GDD §5.1): hambre, sed, temperatura corporal y stamina.
## Valores en /data/survival/*.tres. 🔶 Todos son placeholders de tuning (el GDD no fija números).
## Los ritmos van en horas de juego (1 día de juego = 24 h = 60 min reales por defecto).

@export_group("Hambre y sed")
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var hunger_per_hour: float = 0.0
@export var thirst_per_hour: float = 0.0
## Multiplicador de hambre y sed con el estómago destruido (GDD §5.1).
@export var destroyed_stomach_multiplier: float = 1.0
## Daño por hora de juego al tórax con hambre o sed a 0.
@export var starvation_damage_per_hour: float = 0.0
## Por debajo de este valor el HUD avisa (GDD §14: "cuando son críticos").
@export var critical_level: float = 30.0

@export_group("Temperatura")
## Temperatura ambiente (°C) con clima normalizado 0 y 1.
@export var climate_min_c: float = -10.0
@export var climate_max_c: float = 40.0
## Bajada de la temperatura ambiente de noche (°C).
@export var night_drop_c: float = 0.0
## Fuera de este rango de temperatura ambiente el cuerpo se enfría o se calienta.
@export var comfort_min_c: float = 0.0
@export var comfort_max_c: float = 0.0
## °C de temperatura corporal por hora de juego y por °C fuera del rango de confort.
@export var body_drift_per_hour_per_c: float = 0.0
## Recuperación hacia 37 °C por hora de juego dentro del confort.
@export var body_recovery_per_hour: float = 0.0
@export var hypothermia_c: float = 35.0
@export var hyperthermia_c: float = 39.0
## Daño por hora de juego al tórax con hipotermia.
@export var hypothermia_damage_per_hour: float = 0.0
## Multiplicador de sed con hipertermia.
@export var hyperthermia_thirst_multiplier: float = 1.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
## Consumo por segundo real esprintando y apuntando; coste de un salto.
@export var sprint_drain_per_s: float = 0.0
@export var aim_drain_per_s: float = 0.0
@export var jump_cost: float = 0.0
@export var regen_per_s: float = 0.0
## Segundos sin gastar stamina antes de empezar a recuperar.
@export var regen_delay_s: float = 0.0
## Con hipotermia la stamina se recupera más despacio.
@export var hypothermia_regen_multiplier: float = 1.0
