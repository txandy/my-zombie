class_name PlayerInputFrame
extends RefCounted
## Entrada del jugador en un tick de física.
##
## El movimiento se simula a partir de este objeto y no leyendo Input directamente,
## para que en coop (M7) el cliente pueda enviar sus frames al host y para poder
## inyectar entrada en los tests.

## x: derecha (+) / izquierda (-). y: adelante (+) / atrás (-). Longitud <= 1.
var move: Vector2 = Vector2.ZERO
## Giro de cámara en radianes (x: yaw, y: pitch).
var look_delta: Vector2 = Vector2.ZERO
var jump: bool = false
var sprint: bool = false
## Pulsaciones de este tick (las posturas funcionan como toggle).
var crouch_toggled: bool = false
var prone_toggled: bool = false
## -1: izquierda, 0: nada, 1: derecha.
var lean: int = 0
