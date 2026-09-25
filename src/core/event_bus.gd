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
