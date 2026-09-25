class_name PlayerMovementProfile
extends Resource
## Parámetros de movimiento del jugador. Los valores viven en /data/player/*.tres.
##
## 🔶 El GDD no fija velocidades ni alturas: los valores de default_movement_profile.tres
## son placeholders de tuning (M0) y deben ajustarse en playtest.

@export_group("Velocidades (m/s)")
@export var walk_speed: float = 0.0
@export var sprint_speed: float = 0.0
@export var crouch_speed: float = 0.0
@export var prone_speed: float = 0.0

@export_group("Aceleración (m/s²)")
@export var acceleration: float = 0.0
@export var deceleration: float = 0.0
@export var air_acceleration: float = 0.0

@export_group("Salto")
## Velocidad vertical inicial del salto (m/s).
@export var jump_velocity: float = 0.0

@export_group("Postura (m)")
@export var capsule_radius: float = 0.0
@export var standing_height: float = 0.0
@export var crouch_height: float = 0.0
## Mínimo 2 × capsule_radius (la cápsula no puede ser más baja que su diámetro).
@export var prone_height: float = 0.0
## Distancia de los ojos a la parte superior de la cápsula.
@export var eye_offset: float = 0.0
## Velocidad a la que cambia la altura al cambiar de postura (m/s).
@export var posture_change_speed: float = 0.0

@export_group("Asomarse (lean)")
@export var lean_angle_deg: float = 0.0
## Desplazamiento lateral de la cámara al asomarse (m).
@export var lean_offset: float = 0.0
## Velocidad de transición del lean (fracción por segundo).
@export var lean_speed: float = 0.0
