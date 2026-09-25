extends Node
## Bus de señales globales para comunicar sistemas desacoplados (autoload `EventBus`).
##
## Solo señales tipadas, sin estado ni lógica. Cada sistema añade aquí las suyas
## cuando se implemente; la comunicación dentro de un mismo sistema usa señales locales.

## Se ha iniciado una sesión de juego (host local o conexión a un host).
@warning_ignore("unused_signal")
signal session_started(world_seed: int)

## La sesión de juego ha terminado.
@warning_ignore("unused_signal")
signal session_ended()

## Un sonido audible para la IA (GDD §5.2, §11.2): disparos, pasos, puertas, construcción.
## `radius_m` es la distancia máxima a la que se oye con audición normal.
@warning_ignore("unused_signal")
signal sound_emitted(position: Vector3, radius_m: float, kind: StringName, source: Node)

## Ha empezado un día nuevo (a las 00:00). `day` empieza en 1.
@warning_ignore("unused_signal")
signal day_started(day: int)

## Cambio entre día y noche (GDD §4.5).
@warning_ignore("unused_signal")
signal night_changed(is_night: bool)
