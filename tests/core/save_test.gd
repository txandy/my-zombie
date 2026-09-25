# Tests del guardado (GDD §13): serialización de objetos, inventario y salud, caché del
# mundo, archivos y migraciones, y el criterio de M6 de extremo a extremo:
# "la base persiste tras cargar la partida".
extends GdUnitTestSuite

const WORLD_SCENE: String = "res://scenes/world/world.tscn"
const FIXTURE_PATH: String = "res://tests/world/generation/fixtures/hash_fixture_settings.tres"
const TEST_SAVE: String = "test_save_roundtrip"

var _catalog: ItemCatalog


func before() -> void:
	_catalog = ItemCatalog.load_default()


func after() -> void:
	SaveSystem.delete_save(TEST_SAVE)
	SaveSystem.migrations.clear()


func _item(id: String, qty: int = 1) -> ItemInstance:
	return ItemInstance.new(_catalog.get_item(StringName(id)), qty)


func test_item_roundtrip_with_nested_contents_and_state() -> void:
	var backpack: ItemInstance = _item("backpack_small")
	var rifle: ItemInstance = _item("assault_rifle")
	rifle.state["rounds"] = 12
	rifle.state["ammo"] = load("res://data/combat/ammo/762x39_hp.tres")
	backpack.contents.place(rifle, 0, Vector2i(0, 0), true)
	backpack.contents.insert_anywhere(_item("ammo_762x39_ps", 42))
	var restored: ItemInstance = ItemSerializer.item_from_dict(ItemSerializer.item_to_dict(backpack), _catalog)
	assert_str(String(restored.uuid)).is_equal(String(backpack.uuid))
	var restored_rifle: ItemInstance = restored.contents.find(rifle.uuid)
	assert_int(int(restored_rifle.state.rounds)).is_equal(12)
	assert_object(restored_rifle.state.ammo).is_same(rifle.state.ammo)
	assert_bool(restored.contents.locate(restored_rifle).rotated as bool).is_true()
	assert_int(restored.contents.count_ammo(&"762x39_ps")).is_equal(42)


func test_armor_durability_survives() -> void:
	var vest: ItemInstance = _item("vest_class4")
	vest.durability = 17.5
	var restored: ItemInstance = ItemSerializer.item_from_dict(ItemSerializer.item_to_dict(vest), _catalog)
	assert_float(restored.durability).is_equal(17.5)


func test_new_items_never_reuse_loaded_uuids() -> void:
	var data: Dictionary = ItemSerializer.item_to_dict(_item("bandage"))
	data.uuid = "item_999999"
	ItemSerializer.item_from_dict(data, _catalog)
	assert_int(String(_item("bandage").uuid).trim_prefix("item_").to_int()).is_greater(999999)


func test_health_roundtrip() -> void:
	var health := HealthComponent.new()
	health.profile = load("res://data/combat/human_health_profile.tres") as HealthProfile
	add_child(health)
	health.apply_damage(BodyZones.Zone.LEFT_ARM, 30.0, null)
	health.infect()
	var other := HealthComponent.new()
	other.profile = health.profile
	add_child(other)
	other.from_save(health.to_save())
	assert_float(other.hp(BodyZones.Zone.LEFT_ARM)).is_equal(30.0)
	assert_bool(other.infected).is_true()
	health.free()
	other.free()


func test_world_cache_roundtrip_and_corruption() -> void:
	var data: WorldData = WorldGenerator.generate(4242, load(FIXTURE_PATH) as WorldGenSettings)
	var dict: Dictionary = WorldCache.to_dict(data)
	var bytes: PackedByteArray = var_to_bytes(dict)
	var restored: WorldData = WorldCache.from_dict(bytes_to_var(bytes) as Dictionary)
	assert_str(restored.compute_hash()).is_equal(data.compute_hash())
	dict.heights[10] += 1.0
	assert_object(WorldCache.from_dict(dict)).is_null()


func test_files_and_migrations() -> void:
	SaveSystem.write_state(TEST_SAVE, {"seed": 1}, {"answer": 42}, {"host": {"pos": Vector3(1, 2, 3)}})
	assert_bool(SaveSystem.exists(TEST_SAVE)).is_true()
	assert_int(int(SaveSystem.read_state(TEST_SAVE).answer)).is_equal(42)
	assert_vector(SaveSystem.read_player(TEST_SAVE, "host").pos as Vector3).is_equal(Vector3(1, 2, 3))
	assert_int(int(SaveSystem.read_meta(TEST_SAVE).save_version)).is_equal(SaveSystem.SAVE_VERSION)
	# Un estado de una versión anterior pasa por las migraciones registradas.
	SaveSystem.migrations[0] = func(state: Dictionary) -> Dictionary:
		state["answer"] = int(state.old_answer)
		return state
	var old: Dictionary = SaveSystem.migrate({"old_answer": 7}, 0)
	assert_int(int(old.answer)).is_equal(7)


# --- Criterio de M6 ---

func _open_world() -> Node3D:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as Node3D
	world.set(&"autosave_interval_s", 0.0)
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return world


func test_base_and_world_state_persist_after_loading() -> void:
	SaveSystem.pending_seed = 777001
	var world: Node3D = await _open_world()
	var save_name: String = String(world.get(&"save_name"))
	assert_bool(bool(world.get(&"loaded_from_cache"))).is_false()
	var player := world.get_node("Player") as Player
	var manager := world.get_node("Buildings") as BuildingManager
	# Construir una base pequeña de verdad (a través del host) cerca del jugador.
	var wood := load("res://data/building/materials/wood.tres") as BuildingMaterial
	player.inventory.inventory.equip(_item("backpack_large"), Inventory.Slot.BACKPACK)
	player.inventory.give(_item("wood", 100))
	player.inventory.give(_item("wood", 100))
	var spot: Vector3 = player.global_position + (-player.global_basis.z) * 3.0
	var foundation := load("res://data/building/pieces/foundation.tres") as BuildingPieceDefinition
	var wall := load("res://data/building/pieces/wall.tres") as BuildingPieceDefinition
	# Busca un sitio donde el terreno lo permita alrededor del jugador.
	for attempt: int in 12:
		var probe: Vector3 = player.global_position + Vector3(cos(attempt), 0, sin(attempt)) * 3.5
		var slot: Dictionary = manager.resolve_slot(foundation, probe - Vector3.UP * 1.0, 0.0)
		if manager.placement_error(foundation, slot) == "":
			spot = probe - Vector3.UP * 1.0
			break
	manager.request_place(player, foundation, wood, spot, 0.0)
	assert_int(manager.bases.size()).is_equal(1)
	var base: BaseModel = manager.bases[0]
	var center: Vector3 = base.piece_transform(foundation, Vector3i.ZERO, -1).origin
	manager.request_place(player, wall, wood, center + Vector3(0, 0.5, -1.3), 0.0)
	var pieces_before: int = base.pieces.size()
	var damaged: BaseModel.Piece = base.pieces.values()[0]
	damaged.hp -= 40.0
	var hp_before: float = damaged.hp
	# Estado del jugador y del mundo.
	GameState.day = 3
	GameState.hour = 17.5
	player.survival.hunger = 42.0
	assert_int(world.call(&"save_game")).is_equal(OK)
	world.free()
	await get_tree().process_frame

	SaveSystem.pending_load = save_name
	var loaded: Node3D = await _open_world()
	assert_bool(bool(loaded.get(&"loaded_from_cache"))).is_true()
	var loaded_manager := loaded.get_node("Buildings") as BuildingManager
	assert_int(loaded_manager.bases.size()).is_equal(1)
	var loaded_base: BaseModel = loaded_manager.bases[0]
	assert_int(loaded_base.pieces.size()).is_equal(pieces_before)
	var loaded_piece: BaseModel.Piece = loaded_base.find_uid(damaged.uid)
	assert_float(loaded_piece.hp).is_equal_approx(hp_before, 0.001)
	assert_object(loaded_manager.piece_node(loaded_base.id, damaged.uid)).is_not_null()
	assert_int(GameState.day).is_equal(3)
	assert_float(GameState.hour).is_equal_approx(17.5, 0.01)
	var loaded_player := loaded.get_node("Player") as Player
	assert_float(loaded_player.survival.hunger).is_equal_approx(42.0, 0.01)
	assert_int(BuildingManager.count_item(loaded_player.inventory.inventory, _catalog.get_item(&"wood"))).is_equal(
			200 - foundation.cost(wood) - wall.cost(wood))
	loaded.free()
	SaveSystem.delete_save(save_name)
