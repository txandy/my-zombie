# Tests de validación de solicitudes de red del inventario (obligatorios, AGENTS.md §5).
extends GdUnitTestSuite

var _component: InventoryComponent
var _box: ItemDefinition
var _rejections: Array[String] = []


func before_test() -> void:
	NetManager.start_single_player()
	_box = ItemDefinition.new()
	_box.id = &"box"
	_component = InventoryComponent.new()
	_component.profile = load("res://data/inventory/human_inventory_profile.tres") as InventoryProfile
	add_child(_component)
	_rejections.clear()
	_component.request_rejected.connect(func(reason: String) -> void: _rejections.append(reason))


func after_test() -> void:
	_component.free()
	NetManager.close()


func test_owner_can_move_item() -> void:
	var box := ItemInstance.new(_box)
	_component.give(box)
	_component.request_move(box.uuid, Inventory.POCKETS_ID, 3, Vector2i.ZERO, false)
	assert_dict(_component.inventory.pockets.locate(box)).is_equal({"grid": 3, "cell": Vector2i.ZERO, "rotated": false})


func test_other_peer_is_ignored() -> void:
	var box := ItemInstance.new(_box)
	_component.give(box)
	_component.owner_peer_id = 5
	_component.request_move(box.uuid, Inventory.POCKETS_ID, 3, Vector2i.ZERO, false)
	assert_int(_component.inventory.pockets.locate(box).grid as int).is_equal(0)


func test_unknown_item_is_rejected() -> void:
	_component.request_move(&"item_does_not_exist", Inventory.POCKETS_ID, 0, Vector2i.ZERO, false)
	assert_array(_rejections).contains(["objeto fuera de alcance"])


func test_items_in_closed_container_are_out_of_reach() -> void:
	var crate := ItemContainer.new(&"crate_7", [Vector2i(3, 3)])
	var loot := ItemInstance.new(_box)
	crate.insert_anywhere(loot)
	_component.request_move(loot.uuid, Inventory.POCKETS_ID, 0, Vector2i.ZERO, false)
	assert_object(loot.location()).is_same(crate)
	_component.open_external(crate)
	_component.request_move(loot.uuid, Inventory.POCKETS_ID, 0, Vector2i.ZERO, false)
	assert_object(loot.location()).is_same(_component.inventory.pockets)
	_component.close_external(&"crate_7")
	assert_object(_component.inventory.container_by_id(&"crate_7")).is_null()


func test_cannot_move_into_closed_container() -> void:
	var crate := ItemContainer.new(&"crate_8", [Vector2i(3, 3)])
	var box := ItemInstance.new(_box)
	_component.give(box)
	_component.request_move(box.uuid, &"crate_8", 0, Vector2i.ZERO, false)
	assert_object(box.location()).is_same(_component.inventory.pockets)
	assert_array(_rejections).contains(["destino no disponible"])


func test_drop_emits_item_and_removes_it() -> void:
	var box := ItemInstance.new(_box)
	_component.give(box)
	var dropped: Array[ItemInstance] = []
	_component.item_dropped.connect(func(item: ItemInstance) -> void: dropped.append(item))
	_component.request_drop(box.uuid)
	assert_array(dropped).contains_exactly([box])
	assert_object(_component.inventory.find(box.uuid)).is_null()


func test_client_cannot_give_items() -> void:
	NetManager.join("127.0.0.1", 24692)
	var box := ItemInstance.new(_box)
	assert_int(_component.give(box)).is_equal(1)
	assert_object(box.location()).is_null()
