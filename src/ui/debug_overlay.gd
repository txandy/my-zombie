extends Label
## Overlay de depuración: seed de la sesión, FPS y posición del jugador.
## Solo lee estado; nunca lo modifica (AGENTS.md §4).

@export var player_path: NodePath

var _player: Node3D


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D


func _process(_delta: float) -> void:
	var pos: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	var minutes: int = int(GameState.hour * 60.0) % 60
	text = "día %d %02d:%02d · seed %d · %d FPS · pos (%.0f, %.0f, %.0f)" % [GameState.day, int(GameState.hour),
			minutes, GameState.world_seed, Engine.get_frames_per_second(), pos.x, pos.y, pos.z]
