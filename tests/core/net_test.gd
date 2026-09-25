# Tests de red unitarios: visibilidad por peers listos y contenedores por red.
extends GdUnitTestSuite


func after_test() -> void:
	NetManager.close()


func test_only_ready_peers_receive_replication() -> void:
	assert_bool(NetManager.is_peer_ready(1)).is_true()
	assert_bool(NetManager.is_peer_ready(42)).is_false()
	NetManager.ready_peers[42] = true
	assert_bool(NetManager.is_peer_ready(42)).is_true()
	assert_array(NetManager.ready_clients()).contains_exactly([42])


func test_container_roundtrip_keeps_id_and_grids() -> void:
	var catalog: ItemCatalog = ItemCatalog.load_default()
	var crate := ItemContainer.new(&"crate_9", [Vector2i(3, 2), Vector2i(1, 1)])
	crate.place(ItemInstance.new(catalog.get_item(&"bandage"), 3), 1, Vector2i.ZERO, false)
	var copy: ItemContainer = ItemSerializer.container_from_dict(ItemSerializer.container_to_dict(crate), catalog)
	assert_str(String(copy.id)).is_equal("crate_9")
	assert_int(copy.grids.size()).is_equal(2)
	assert_int(copy.grids[0].width).is_equal(3)
	assert_int(copy.grids[1].item_at(Vector2i.ZERO).quantity).is_equal(3)


func test_player_is_local_only_for_its_peer() -> void:
	NetManager.start_single_player()
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	player.peer_id = 5
	add_child(player)
	assert_bool(player.is_local()).is_false()
	assert_int(player.inventory.owner_peer_id).is_equal(5)
	assert_bool(player.camera().current).is_false()
	player.free()
