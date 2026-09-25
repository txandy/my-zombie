# Tests del loot en el mundo: contenedores que se rellenan una vez y de forma reproducible,
# apertura por interacción, cierre al alejarse, y tirar/recoger objetos del suelo.
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const CRATE_SCENE: String = "res://scenes/loot/military_crate.tscn"

var _world: Node3D
var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	GameState.world_seed = 4242
	_world = auto_free(Node3D.new())
	add_child(_world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	floor_body.position.y = -0.5
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_player.starting_kit = load("res://data/inventory/kits/survivor_kit.tres") as StartingKit
	_world.add_child(_player)
	_player.set_physics_process(false)


func after_test() -> void:
	NetManager.close()


func _crate(at: Vector3, id: StringName) -> LootContainer:
	var crate: LootContainer = (load(CRATE_SCENE) as PackedScene).instantiate() as LootContainer
	crate.container_id = id
	crate.poi_tier = 2
	_world.add_child(crate)
	crate.global_position = at
	return crate


func _contents(crate: LootContainer) -> String:
	var parts: PackedStringArray = []
	for item: ItemInstance in crate.item_container.items():
		parts.append("%s×%d" % [item.definition.id, item.quantity])
	parts.sort()
	return ",".join(parts)


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_fills_when_player_is_near_and_only_once() -> void:
	var far: LootContainer = _crate(Vector3(0, 0, -100), &"far")
	var near: LootContainer = _crate(Vector3(0, 0, -10), &"near")
	await _ticks(40)
	assert_bool(near.is_filled).is_true()
	assert_bool(far.is_filled).is_false()
	var first: String = _contents(near)
	near.fill()
	assert_str(_contents(near)).is_equal(first)


func test_same_seed_and_id_same_loot() -> void:
	var a: LootContainer = _crate(Vector3(0, 0, -200), &"poi_3/Storage")
	a.fill()
	var b: LootContainer = _crate(Vector3(0, 0, -300), &"poi_3/Storage")
	b.fill()
	assert_str(_contents(a)).is_equal(_contents(b))
	var c: LootContainer = _crate(Vector3(0, 0, -400), &"poi_4/Storage")
	c.fill()
	GameState.world_seed = 1
	var d: LootContainer = _crate(Vector3(0, 0, -500), &"poi_3/Storage")
	d.fill()
	# Con otro id u otra seed el loot cambia (casi seguro con esta tabla).
	assert_bool(_contents(c) != _contents(a) or _contents(d) != _contents(a)).is_true()


func test_interact_opens_and_distance_closes() -> void:
	var crate: LootContainer = _crate(Vector3(0, 0, -1.5), &"open_me")
	crate.interact(_player)
	assert_object(_player.inventory.inventory.container_by_id(&"open_me")).is_same(crate.item_container)
	_player.global_position = Vector3(0, 0, 20)
	await _ticks(2)
	assert_object(_player.inventory.inventory.container_by_id(&"open_me")).is_null()


func test_loot_can_be_moved_into_inventory() -> void:
	var crate: LootContainer = _crate(Vector3(0, 0, -1.5), &"take_from_me")
	crate.interact(_player)
	var loot := ItemInstance.new(load("res://data/items/electronics.tres") as ItemDefinition)
	crate.item_container.insert_anywhere(loot)
	var inv: Inventory = _player.inventory.inventory
	var pocket: int = _free_pocket(inv)
	_player.inventory.request_move(loot.uuid, Inventory.POCKETS_ID, pocket, Vector2i.ZERO, false)
	assert_object(loot.location()).is_same(inv.pockets)
	assert_object(crate.item_container.find(loot.uuid)).is_null()


func test_drop_and_pick_up() -> void:
	var inv: Inventory = _player.inventory.inventory
	var bandage: ItemInstance = inv.pockets.items().filter(
			func(i: ItemInstance) -> bool: return i.definition.id == &"bandage")[0]
	_player.inventory.request_drop(bandage.uuid)
	var dropped: Array[Node] = get_tree().get_nodes_in_group(&"world_item")
	assert_int(dropped.size()).is_equal(1)
	var world_item := dropped[0] as WorldItem
	assert_object(world_item.item).is_same(bandage)
	world_item.interact(_player)
	assert_object(inv.find(bandage.uuid)).is_same(bandage)
	await _ticks(1)
	assert_int(get_tree().get_nodes_in_group(&"world_item").size()).is_equal(0)


func _free_pocket(inv: Inventory) -> int:
	for g: int in inv.pockets.grids.size():
		if inv.pockets.grids[g].free_cells() > 0:
			return g
	return -1
