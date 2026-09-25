class_name PerceptionRules
extends Resource
## Reglas globales de percepción y sonido (GDD §5.2, §11.2). Valores en /data/ai/perception_rules.tres.
## 🔶 Todos los valores son placeholders de tuning.

@export_group("Visibilidad")
## Visibilidad (multiplicador) al límite del rango de visión; 1 a distancia 0.
@export var visibility_at_max_range: float = 0.0
@export var crouch_visibility: float = 1.0
@export var prone_visibility: float = 1.0
## Multiplicador si el objetivo se mueve (más fácil de ver).
@export var moving_visibility: float = 1.0
## Visibilidad mínima de noche (con ambient_light = 0).
@export var night_visibility: float = 1.0
## Pérdida de detección por segundo sin ver al objetivo (fracción del medidor).
@export var detection_decay_per_s: float = 0.0
## Intervalo entre comprobaciones de visión (s). Los raycasts no se hacen cada frame.
@export var vision_interval_s: float = 0.2

@export_group("Sonido")
@export var gunshot_radius_m: float = 0.0
@export var walk_step_radius_m: float = 0.0
@export var sprint_step_radius_m: float = 0.0
@export var crouch_step_radius_m: float = 0.0
@export var prone_step_radius_m: float = 0.0
## Metros recorridos entre pasos.
@export var step_distance_m: float = 0.0

@export_group("Supresión")
## Distancia a la trayectoria de una bala a la que suprime.
@export var suppression_radius_m: float = 0.0
## Supresión que añade cada bala cercana (0-1) y su caída por segundo.
@export var suppression_per_bullet: float = 0.0
@export var suppression_decay_per_s: float = 0.0
