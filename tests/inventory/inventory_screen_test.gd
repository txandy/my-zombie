# Test de humo de la UI de inventario: se abre, muestra el contenedor externo y se cierra
# sin errores, bloqueando y devolviendo la entrada de juego.
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"


func test_open_with_container_and_close() -> void:
	NetManager.start_single_player()
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.starting_kit = load("res://data/inventory/kits/range_kit.tres") as StartingKit
	add_child(player)
	player.set_physics_process(false)
	var screen := player.get_node("HUD/InventoryScreen") as InventoryScreen
	var input := player.get_node("PlayerInput") as PlayerInput
	var crate := ItemContainer.new(&"ui_crate", [Vector2i(4, 4)])
	player.inventory.open_external(crate, null, "caja")
	await get_tree().process_frame
	assert_bool(screen.is_open).is_true()
	assert_bool(input.gameplay_enabled).is_false()
	screen.set_open(false)
	assert_bool(input.gameplay_enabled).is_true()
	assert_object(player.inventory.inventory.container_by_id(&"ui_crate")).is_null()
	player.free()
	NetManager.close()
