extends Node3D
## Arena de pruebas de IA (M4): sesión single player, malla de navegación horneada de la
## geometría de la escena y LOD de IA. Los NPCs y coberturas están en la escena.


func _ready() -> void:
	NetManager.start_single_player()
	GameState.start_session(GameState.random_world_seed())
	var manager := AIManager.new()
	manager.name = "AIManager"
	add_child(manager)
	NavRegionBuilder.bake(self, Vector3.ZERO, 120.0, null, $Geometry, null)
