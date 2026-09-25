class_name ZombieProfile
extends Resource
## Parámetros de un tipo de zombi (GDD §11.1). Valores en /data/ai/*.tres.
## 🔶 Todos son placeholders de tuning.

@export var type_id: StringName = &""

@export_group("Movimiento")
## GDD: el básico es lento de día y rápido de noche.
@export var wander_speed: float = 0.0
@export var chase_speed_day: float = 0.0
@export var chase_speed_night: float = 0.0
@export var turn_speed_deg: float = 0.0

@export_group("Percepción (barata)")
@export var sight_range_m: float = 0.0
@export var sight_fov_deg: float = 0.0
## Radio en el que "huele" a un jugador aunque no le vea.
@export var smell_radius_m: float = 0.0
@export var hearing_multiplier: float = 1.0
## Segundos persiguiendo sin percibir al objetivo antes de rendirse.
@export var give_up_s: float = 0.0
## Intervalo entre comprobaciones de percepción (s).
@export var perception_interval_s: float = 0.5

@export_group("Ataque")
@export var attack_range_m: float = 0.0
@export var attack_interval_s: float = 0.0
@export var attack_damage: float = 0.0
## Probabilidad de infectar con una mordedura que llega a hacer daño.
@export_range(0.0, 1.0) var infection_chance: float = 0.0
## Daño a piezas de construcción por golpe (M6).
@export var structure_damage: float = 0.0
