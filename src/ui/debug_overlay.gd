extends Label
## Overlay de depuración: día y hora, seed, FPS, posición y red.
## Solo lee estado; nunca lo modifica (AGENTS.md §4).

## Jugador a mostrar (lo fija la escena del mundo al crear el jugador local).
var target: Node3D


func _process(_delta: float) -> void:
	var pos: Vector3 = target.global_position if is_instance_valid(target) else Vector3.ZERO
	var minutes: int = int(GameState.hour * 60.0) % 60
	var role: String = "host" if multiplayer.is_server() else "cliente"
	if not NetManager.is_online():
		role = "single"
	text = "día %d %02d:%02d · seed %d · %s · %d FPS · pos (%.0f, %.0f, %.0f)" % [GameState.day,
			int(GameState.hour), minutes, GameState.world_seed, role, Engine.get_frames_per_second(), pos.x, pos.y, pos.z]
