extends Node3D
## Escena de pruebas de M0: arranca una sesión single player (host sin clientes).


func _ready() -> void:
	NetManager.start_single_player()
	GameState.start_session(GameState.random_world_seed())
