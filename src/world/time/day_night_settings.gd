class_name DayNightSettings
extends Resource
## Parámetros del ciclo día/noche (GDD §4.1, §4.5). Valores en /data/world/day_night.tres.
## 🔶 Horas de amanecer/anochecer, luces y hordas: placeholders de tuning.

## Duración de un día completo en segundos reales (GDD: 60 min, configurable).
@export var day_length_s: float = 3600.0
@export var start_hour: float = 8.0
@export var sunrise_hour: float = 6.0
@export var sunset_hour: float = 20.0
## Horas de transición (crepúsculo) alrededor del amanecer y el anochecer.
@export var twilight_hours: float = 1.0

@export_group("Luz")
@export var day_sun_energy: float = 1.0
@export var night_sun_energy: float = 0.0
@export var day_color: Color = Color.WHITE
@export var dusk_color: Color = Color(1.0, 0.6, 0.4)
## Luz ambiental (para la IA y el entorno) de noche.
@export var night_ambient: float = 0.08
@export var night_fog_density: float = 0.004
@export var day_fog_density: float = 0.0015

@export_group("Hordas")
## Cada cuántos días hay horda (GDD: inicialmente 7).
@export var horde_every_days: int = 7
