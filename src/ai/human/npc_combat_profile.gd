class_name NPCCombatProfile
extends Resource
## Perfil de combate de un arquetipo de NPC humano (GDD §11.2). Valores en /data/ai/*.tres.
## Todo el tuning de "difícil pero justo" vive aquí, sin tocar código.
## 🔶 Arquetipos y valores: placeholders de tuning (GDD §18.2).

@export var archetype: StringName = &""

@export_group("Percepción")
@export var vision_range_m: float = 0.0
## Ángulo total del cono de visión.
@export var vision_fov_deg: float = 0.0
## Segundos para detectar a un objetivo totalmente visible (visibilidad 1).
@export var detection_time_s: float = 0.0
## Multiplicador del radio de los sonidos que oye.
@export var hearing_multiplier: float = 1.0
## Segundos hasta que la confianza en la última posición conocida cae a 0.
@export var memory_duration_s: float = 0.0

@export_group("Reacción y puntería")
## Tiempo de reacción antes del primer disparo tras detectar (GDD: 0.25-0.8 s según arquetipo).
@export var reaction_time_min_s: float = 0.0
@export var reaction_time_max_s: float = 0.0
## Error de apuntado inicial y final (semiángulo en grados) y tiempo de convergencia.
@export var base_spread_deg: float = 0.0
@export var min_spread_deg: float = 0.0
@export var aim_settle_time_s: float = 0.0
## Fracción del asentamiento que se pierde al dejar de ver al objetivo.
@export_range(0.0, 1.0) var unsettle_on_lost_sight: float = 0.0
## El error crece con la distancia: +fracción por cada 100 m.
@export var spread_per_100m: float = 0.0
## Grados extra por cada m/s de velocidad lateral del objetivo.
@export var spread_per_target_mps: float = 0.0
## Fracción del movimiento del objetivo durante el vuelo de la bala que el NPC adelanta (0-1).
@export_range(0.0, 1.0) var lead_fraction: float = 0.0
## Multiplicador del error si el propio NPC se mueve.
@export var self_moving_spread_multiplier: float = 1.0
## Grados extra con supresión máxima (recibiendo fuego).
@export var suppression_spread_deg: float = 0.0
## Probabilidad máxima de apuntar a la cabeza (con puntería totalmente asentada).
@export_range(0.0, 1.0) var max_headshot_chance: float = 0.0

@export_group("Disparo")
## Disparos por ráfaga con armas automáticas y pausa entre ráfagas.
@export var burst_min: int = 1
@export var burst_max: int = 1
@export var burst_pause_s: float = 0.0
## Pausa entre disparos con armas semiautomáticas.
@export var semi_interval_s: float = 0.0

@export_group("Movimiento")
@export var walk_speed: float = 0.0
@export var run_speed: float = 0.0
## Giro máximo (grados por segundo).
@export var turn_speed_deg: float = 0.0

@export_group("Táctica")
## Fracción de vida del tórax por debajo de la cual se retira a curarse.
@export_range(0.0, 1.0) var retreat_health_fraction: float = 0.0
## Tendencia a presionar/flanquear frente a quedarse a cubierto (0-1).
@export_range(0.0, 1.0) var aggression: float = 0.0
## Segundos máximos asomado disparando antes de volver a cubrirse.
@export var peek_time_s: float = 0.0
## Segundos a cubierto entre asomadas.
@export var cover_time_s: float = 0.0
## Segundos buscando en la última posición conocida antes de rendirse.
@export var search_time_s: float = 0.0
