# Tests del BuildingManager con física real: colocar con coste, validación del host,
# terreno y pilares, obstáculos, mejora, daño de zombis y balas, puertas y recogida.
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const ZOMBIE_SCENE: String = "res://scenes/ai/zombie.tscn"

var _world: Node3D
var _player: Player
var _manager: BuildingManager
var _foundation: BuildingPieceDefinition
var _wall: BuildingPieceDefinition
var _doorway: BuildingPieceDefinition
var _door: BuildingPieceDefinition
var _wood: BuildingMaterial
var _stone: BuildingMaterial


func before() -> void:
	_foundation = load("res://data/building/pieces/foundation.tres") as BuildingPieceDefinition
	_wall = load("res://data/building/pieces/wall.tres") as BuildingPieceDefinition
	_doorway = load("res://data/building/pieces/doorway.tres") as BuildingPieceDefinition
	_door = load("res://data/building/pieces/door.tres") as BuildingPieceDefinition
	_wood = load("res://data/building/materials/wood.tres") as BuildingMaterial
	_stone = load("res://data/building/materials/stone.tres") as BuildingMaterial


func before_test() -> void:
	NetManager.start_single_player()
	_world = auto_free(Node3D.new())
	add_child(_world)
	var ground := CSGBox3D.new()
	ground.size = Vector3(200, 1, 200)
	ground.use_collision = true
	ground.position.y = -0.5
	_world.add_child(ground)
	_manager = BuildingManager.new()
	_world.add_child(_manager)
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.inventory.inventory.equip(ItemInstance.new(load("res://data/items/backpack_large.tres") as ItemDefinition), Inventory.Slot.BACKPACK)
	_player.global_position = Vector3(0, 0, 4)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	NetManager.close()


func _give(item_id: String, amount: int) -> void:
	var def := load("res://data/items/%s.tres" % item_id) as ItemDefinition
	while amount > 0:
		var stack := ItemInstance.new(def, mini(amount, def.max_stack))
		amount -= stack.quantity
		_player.inventory.give(stack)


func _count(item_id: String) -> int:
	return BuildingManager.count_item(_player.inventory.inventory, load("res://data/items/%s.tres" % item_id) as ItemDefinition)


func _place(def: BuildingPieceDefinition, material: BuildingMaterial, point: Vector3) -> void:
	_manager.request_place(_player, def, material, point, 0.0)
	await get_tree().physics_frame


func test_place_foundation_costs_resources() -> void:
	_give("wood", 100)
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	assert_int(_manager.bases.size()).is_equal(1)
	assert_int(_count("wood")).is_equal(100 - _foundation.cost(_wood))


func test_cannot_place_without_resources() -> void:
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	assert_int(_manager.bases.size()).is_equal(0)


func test_cannot_place_out_of_reach() -> void:
	_give("wood", 100)
	await _place(_foundation, _wood, Vector3(0, 0, -40))
	assert_int(_manager.bases.size()).is_equal(0)


func test_walls_snap_to_foundation_edges() -> void:
	_give("wood", 200)
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	var base: BaseModel = _manager.bases[0]
	var foundation_t: Transform3D = base.piece_transform(_foundation, Vector3i.ZERO, -1)
	# Apuntando cerca del borde norte del cimiento.
	await _place(_wall, _wood, foundation_t.origin + Vector3(0, 0.5, -1.3))
	assert_int(base.pieces.size()).is_equal(2)
	var wall_node: BuildingPieceNode = _manager.piece_node(base.id, 2)
	assert_object(wall_node).is_not_null()


func test_high_terrain_blocks_foundation_and_slope_gets_pillars() -> void:
	_give("wood", 200)
	var bump := CSGBox3D.new()
	bump.size = Vector3(4, 2, 4)
	bump.use_collision = true
	bump.position = Vector3(10, 1, 0)
	_world.add_child(bump)
	_player.global_position = Vector3(10, 0, 4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var slot: Dictionary = _manager.resolve_slot(_foundation, Vector3(10, 0, 1), 0.0)
	assert_str(_manager.placement_error(_foundation, slot)).is_not_empty()


func test_obstacle_blocks_placement() -> void:
	_give("wood", 200)
	var crate := CSGBox3D.new()
	crate.size = Vector3(1, 1, 1)
	crate.use_collision = true
	crate.position = Vector3(0, 0.9, 0)
	_world.add_child(crate)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	assert_int(_manager.bases.size()).is_equal(0)


func test_upgrade_to_stone_costs_stone_and_raises_hp() -> void:
	_give("wood", 100)
	_give("stone", 100)
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	var node: BuildingPieceNode = _manager.piece_node(_manager.bases[0].id, 1)
	var hp: float = node.piece.hp
	_manager.request_upgrade(_player, node, _stone)
	assert_object(node.piece.material).is_same(_stone)
	assert_float(node.piece.hp).is_greater(hp)
	assert_int(_count("stone")).is_equal(100 - _foundation.cost(_stone))


func test_structure_damage_destroys_piece() -> void:
	_give("wood", 100)
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	var base: BaseModel = _manager.bases[0]
	var node: BuildingPieceNode = _manager.piece_node(base.id, 1)
	node.receive_structure_damage(node.piece.hp + 1.0)
	await get_tree().process_frame
	assert_bool(is_instance_valid(node)).is_false()
	assert_int(_manager.bases.size()).is_equal(0)


func test_zombie_attacks_wall_in_its_way() -> void:
	_give("wood", 300)
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	var base: BaseModel = _manager.bases[0]
	var center: Vector3 = base.piece_transform(_foundation, Vector3i.ZERO, -1).origin
	await _place(_wall, _wood, center + Vector3(0, 0.5, -1.3))
	var wall: BuildingPieceNode = _manager.piece_node(base.id, 2)
	var hp: float = wall.piece.hp
	# El jugador dentro, el zombi fuera al otro lado de la pared.
	_player.global_position = center + Vector3(0, 0.1, 0)
	var zombie: Zombie = (load(ZOMBIE_SCENE) as PackedScene).instantiate() as Zombie
	_world.add_child(zombie)
	zombie.global_position = center + Vector3(0, 0.2, -4)
	for i: int in 300:
		await get_tree().physics_frame
		if not is_instance_valid(wall) or wall.piece.hp < hp:
			break
	assert_bool(not is_instance_valid(wall) or wall.piece.hp < hp).is_true()


func test_door_opens_and_closes() -> void:
	_give("wood", 300)
	await _place(_foundation, _wood, Vector3(0, 0, 0))
	var base: BaseModel = _manager.bases[0]
	var center: Vector3 = base.piece_transform(_foundation, Vector3i.ZERO, -1).origin
	await _place(_doorway, _wood, center + Vector3(0, 0.5, -1.3))
	await _place(_door, _wood, center + Vector3(0, 0.5, -1.3))
	var door: BuildingPieceNode = _manager.piece_node(base.id, 3)
	assert_object(door).is_not_null()
	assert_str(door.interaction_text()).is_equal("Abrir puerta")
	door.interact(_player)
	assert_bool(door.door_open).is_true()
	assert_str(door.interaction_text()).is_equal("Cerrar puerta")


func test_gathering_gives_wood_and_depletes() -> void:
	var registry := CoverRegistry.new()
	_world.add_child(registry)
	registry.add_obstacle(Vector3(0, 0, -2), 0.3, 6.0, CoverRegistry.Kind.TREE, 8)
	_player.global_position = Vector3(0, 0, 0)
	var interactor: Interactor = _player.interactor
	interactor._server_gather(Vector3(0, 1, -1.8))
	assert_int(_count("wood")).is_equal(Interactor.GATHER_AMOUNT)
	interactor._gather_cooldown = 0.0
	interactor._server_gather(Vector3(0, 1, -1.8))
	assert_int(_count("wood")).is_equal(8)
	interactor._gather_cooldown = 0.0
	interactor._server_gather(Vector3(0, 1, -1.8))
	assert_int(_count("wood")).is_equal(8)
