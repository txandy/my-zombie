# Tests del inventario del personaje: slots, almacenamiento, movimientos, munición y peso.
extends GdUnitTestSuite

const S := Inventory.Slot

var _profile: InventoryProfile
var _inv: Inventory
var _rifle: ItemDefinition
var _pistol: ItemDefinition
var _helmet: ItemDefinition
var _vest: ItemDefinition
var _rig: ItemDefinition
var _backpack: ItemDefinition
var _ammo: ItemDefinition
var _box: ItemDefinition


func _def(id: StringName, size: Vector2i, category: ItemDefinition.Category, weight: float = 1.0) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.size = size
	def.category = category
	def.weight_kg = weight
	return def


func _with_grids(def: ItemDefinition, grids: Array[Vector2i]) -> ItemDefinition:
	def.container = ContainerSpec.new()
	def.container.grids = grids
	return def


func before() -> void:
	_profile = load("res://data/inventory/human_inventory_profile.tres") as InventoryProfile
	_rifle = _def(&"rifle", Vector2i(4, 2), ItemDefinition.Category.WEAPON, 3.5)
	_rifle.weapon = load("res://data/combat/weapons/assault_rifle.tres") as WeaponDefinition
	_pistol = _def(&"pistol", Vector2i(2, 1), ItemDefinition.Category.WEAPON)
	_pistol.weapon = load("res://data/combat/weapons/pistol.tres") as WeaponDefinition
	_helmet = _def(&"helmet", Vector2i(2, 2), ItemDefinition.Category.ARMOR)
	_helmet.armor = load("res://data/combat/armor/helmet_class3.tres") as ArmorDefinition
	_vest = _def(&"vest", Vector2i(3, 3), ItemDefinition.Category.ARMOR, 8.0)
	_vest.armor = load("res://data/combat/armor/vest_class4.tres") as ArmorDefinition
	_rig = _with_grids(_def(&"rig", Vector2i(2, 3), ItemDefinition.Category.RIG), [Vector2i(2, 2), Vector2i(1, 2)])
	_backpack = _with_grids(_def(&"backpack", Vector2i(4, 4), ItemDefinition.Category.BACKPACK), [Vector2i(5, 5)])
	_ammo = _def(&"ammo", Vector2i(1, 1), ItemDefinition.Category.AMMO, 0.016)
	_ammo.max_stack = 60
	_ammo.ammo = load("res://data/combat/ammo/762x39_ps.tres") as AmmoDefinition
	_box = _def(&"box", Vector2i(1, 1), ItemDefinition.Category.MISC, 2.0)


func before_test() -> void:
	_inv = Inventory.new(_profile)


func test_pockets_are_four_1x1() -> void:
	assert_int(_inv.pockets.grids.size()).is_equal(4)
	for grid: ItemGrid in _inv.pockets.grids:
		assert_int(grid.width * grid.height).is_equal(1)


func test_slot_rules() -> void:
	assert_bool(Inventory.slot_accepts(S.HELMET, _helmet)).is_true()
	assert_bool(Inventory.slot_accepts(S.HELMET, _vest)).is_false()
	assert_bool(Inventory.slot_accepts(S.TORSO, _vest)).is_true()
	assert_bool(Inventory.slot_accepts(S.TORSO, _rig)).is_true()
	assert_bool(Inventory.slot_accepts(S.BACKPACK, _rig)).is_false()
	assert_bool(Inventory.slot_accepts(S.PRIMARY, _rifle)).is_true()
	assert_bool(Inventory.slot_accepts(S.SECONDARY, _rifle)).is_true()
	assert_bool(Inventory.slot_accepts(S.PISTOL, _rifle)).is_false()
	assert_bool(Inventory.slot_accepts(S.PISTOL, _pistol)).is_true()
	assert_bool(Inventory.slot_accepts(S.PRIMARY, _box)).is_false()


func test_equip_into_occupied_slot_fails() -> void:
	assert_bool(_inv.equip(ItemInstance.new(_rifle), S.PRIMARY)).is_true()
	assert_bool(_inv.equip(ItemInstance.new(_rifle), S.PRIMARY)).is_false()


func test_rig_and_backpack_add_storage() -> void:
	assert_int(_inv.storage().size()).is_equal(1)
	_inv.equip(ItemInstance.new(_rig), S.TORSO)
	_inv.equip(ItemInstance.new(_backpack), S.BACKPACK)
	assert_int(_inv.storage().size()).is_equal(3)


func test_store_fills_pockets_then_rig_then_backpack() -> void:
	_inv.equip(ItemInstance.new(_backpack), S.BACKPACK)
	for i: int in 4:
		assert_int(_inv.store(ItemInstance.new(_box))).is_equal(0)
	assert_int(_inv.pockets.items().size()).is_equal(4)
	var fifth := ItemInstance.new(_box)
	assert_int(_inv.store(fifth)).is_equal(0)
	assert_object(fifth.location()).is_same(_inv.item_in(S.BACKPACK).contents)


func test_store_returns_leftover_when_full() -> void:
	for i: int in 4:
		_inv.store(ItemInstance.new(_box))
	var extra := ItemInstance.new(_box)
	assert_int(_inv.store(extra)).is_equal(1)
	assert_object(extra.location()).is_null()


func test_store_merges_ammo_stacks_first() -> void:
	_inv.store(ItemInstance.new(_ammo, 40))
	assert_int(_inv.store(ItemInstance.new(_ammo, 30))).is_equal(0)
	assert_int(_inv.count_ammo(&"762x39_ps")).is_equal(70)
	assert_int(_inv.pockets.items().size()).is_equal(2)


func test_equipped_backpack_cannot_move_into_itself() -> void:
	var backpack := ItemInstance.new(_backpack)
	_inv.equip(backpack, S.BACKPACK)
	assert_bool(_inv.move_to_container(backpack, backpack.contents, 0, Vector2i.ZERO, false)).is_false()
	assert_object(_inv.item_in(S.BACKPACK)).is_same(backpack)


func test_move_from_slot_to_backpack_and_back() -> void:
	var backpack := ItemInstance.new(_backpack)
	var rig := ItemInstance.new(_rig)
	_inv.equip(backpack, S.BACKPACK)
	_inv.equip(rig, S.TORSO)
	assert_bool(_inv.move_to_container(rig, backpack.contents, 0, Vector2i(0, 0), false)).is_true()
	assert_object(_inv.item_in(S.TORSO)).is_null()
	assert_bool(_inv.equip(rig, S.TORSO)).is_true()
	assert_object(rig.location()).is_null()


func test_failed_move_keeps_item_in_place() -> void:
	var backpack := ItemInstance.new(_backpack)
	_inv.equip(backpack, S.BACKPACK)
	var box := ItemInstance.new(_box)
	backpack.contents.place(box, 0, Vector2i(2, 2), false)
	assert_bool(_inv.move_to_container(box, _inv.pockets, 9, Vector2i.ZERO, false)).is_false()
	assert_dict(backpack.contents.locate(box)).is_equal({"grid": 0, "cell": Vector2i(2, 2), "rotated": false})


func test_take_ammo_across_containers_removes_empty_stacks() -> void:
	_inv.equip(ItemInstance.new(_backpack), S.BACKPACK)
	_inv.pockets.insert_anywhere(ItemInstance.new(_ammo, 10))
	_inv.item_in(S.BACKPACK).contents.insert_anywhere(ItemInstance.new(_ammo, 50))
	assert_int(_inv.take_ammo(&"762x39_ps", 30)).is_equal(30)
	assert_int(_inv.count_ammo(&"762x39_ps")).is_equal(30)
	assert_int(_inv.pockets.items().size()).is_equal(0)
	assert_int(_inv.take_ammo(&"762x39_ps", 100)).is_equal(30)
	assert_int(_inv.take_ammo(&"762x39_ps", 5)).is_equal(0)


func test_split_and_merge() -> void:
	var stack := ItemInstance.new(_ammo, 40)
	_inv.pockets.place(stack, 0, Vector2i.ZERO, false)
	assert_bool(_inv.split_to(stack, 15, _inv.pockets, 1, Vector2i.ZERO, false)).is_true()
	var part: ItemInstance = _inv.pockets.grids[1].item_at(Vector2i.ZERO)
	assert_int(part.quantity).is_equal(15)
	assert_bool(_inv.split_to(stack, 5, _inv.pockets, 1, Vector2i.ZERO, false)).is_false()
	assert_bool(_inv.merge(part, stack)).is_true()
	assert_int(stack.quantity).is_equal(40)
	assert_object(part.location()).is_null()


func test_find_covers_slots_storage_and_external() -> void:
	var backpack := ItemInstance.new(_backpack)
	_inv.equip(backpack, S.BACKPACK)
	var inside := ItemInstance.new(_box)
	backpack.contents.insert_anywhere(inside)
	var crate := ItemContainer.new(&"crate_1", [Vector2i(4, 4)])
	var loot := ItemInstance.new(_box)
	crate.insert_anywhere(loot)
	assert_object(_inv.find(backpack.uuid)).is_same(backpack)
	assert_object(_inv.find(inside.uuid)).is_same(inside)
	assert_object(_inv.find(loot.uuid)).is_null()
	_inv.external[crate.id] = crate
	assert_object(_inv.find(loot.uuid)).is_same(loot)
	assert_object(_inv.container_by_id(&"crate_1")).is_same(crate)


func test_weight_slows_down() -> void:
	assert_float(_inv.speed_multiplier()).is_equal(1.0)
	_inv.equip(ItemInstance.new(_backpack), S.BACKPACK)
	for i: int in 25:
		_inv.item_in(S.BACKPACK).contents.insert_anywhere(ItemInstance.new(_box))
	# 1 (mochila) + 25 × 2 = 51 kg: entre 25 y 55.
	var expected: float = lerpf(1.0, _profile.overweight_speed_multiplier, inverse_lerp(25.0, 55.0, 51.0))
	assert_float(_inv.speed_multiplier()).is_equal_approx(expected, 0.0001)


func test_unequip_needs_space() -> void:
	_inv.equip(ItemInstance.new(_rifle), S.PRIMARY)
	assert_bool(_inv.unequip_to_storage(S.PRIMARY)).is_false()
	assert_object(_inv.item_in(S.PRIMARY)).is_not_null()
	_inv.equip(ItemInstance.new(_backpack), S.BACKPACK)
	assert_bool(_inv.unequip_to_storage(S.PRIMARY)).is_true()
