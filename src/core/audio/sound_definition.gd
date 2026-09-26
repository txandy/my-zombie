class_name SoundDefinition
extends Resource
## Un sonido del juego (GDD §15). Valores en data/audio/sound_library.tres.
## Si tiene varias variantes, se elige una al azar cada vez.

@export var id: StringName = &""
@export var streams: Array[AudioStream] = []
@export var volume_db: float = 0.0
## Variación aleatoria del tono (0.1 = ±10 %).
@export var pitch_variation: float = 0.0
## Posicional (3D) o de interfaz (se oye igual en todas partes).
@export var positional: bool = true
## Distancia a partir de la que ya no se oye (m).
@export var max_distance_m: float = 60.0
## Distancia a la que se oye a volumen completo (más grande = se oye más lejos).
@export var unit_size: float = 5.0
## Tiempo mínimo entre dos reproducciones del mismo sonido (evita saturar).
@export var min_interval_s: float = 0.0
