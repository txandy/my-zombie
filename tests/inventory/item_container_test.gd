# Tests del modelo de inventario (obligatorios, AGENTS.md §5): colocación, rotación,
# contenedores anidados y stacks.
extends GdUnitTestSuite

var _rifle_def: ItemDefinition   # 4×2, rotable
var _box_def: ItemDefinition     # 1×1
var _ammo_def: ItemDefinition    # 1×1, stack 60
var _flat_def: ItemDefinition    # 3×1, no rotable
var _backpack_def: ItemDefinition  # 3×3, contenedor 4×4
var _pouch_def: ItemDefinition   # 1×2, contenedor 2×2


func _def(id: StringName, size: Vector2i, stack: int = 1, rotatable: bool = true,
		grids: Array[Vector2i] = []) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.size = size
	def.max_stack = stack
	def.rotatable = rotatable
	def.weight_kg = 1.0
	if not grids.is_empty():
		def.container = ContainerSpec.new()
		def.container.grids = grids
	return def


func before() -> void:
	_rifle_def = _def(&"rifle", Vector2i(4, 2))
	_box_def = _def(&"box", Vector2i(1, 1))
	_ammo_def = _def(&"ammo", Vector2i(1, 1), 60)
	_flat_def = _def(&"flat", Vector2i(3, 1), 1, false)
	_backpack_def = _def(&"backpack", Vector2i(3, 3), 1, true, [Vector2i(4, 4)])
	_pouch_def = _def(&"pouch", Vector2i(1, 2), 1, true, [Vector2i(2, 2)])


func _container(size: Vector2i) -> ItemContainer:
	return ItemContainer.new(&"test", [size])


# --- Colocación ---

func test_place_requires_all_footprint_cells_free() -> void:
	var c := _container(Vector2i(5, 3))
	var rifle := ItemInstance.new(_rifle_def)
	assert_bool(c.place(rifle, 0, Vector2i(0, 0), false)).is_true()
	var box := ItemInstance.new(_box_def)
	assert_bool(c.can_place(box, 0, Vector2i(3, 1), false)).is_false()
	assert_bool(c.can_place(box, 0, Vector2i(4, 0), false)).is_true()
	assert_bool(c.can_place(box, 0, Vector2i(0, 2), false)).is_true()


func test_place_out_of_bounds_fails() -> void:
	var c := _container(Vector2i(5, 3))
	var rifle := ItemInstance.new(_rifle_def)
	assert_bool(c.can_place(rifle, 0, Vector2i(2, 0), false)).is_false()
	assert_bool(c.can_place(rifle, 0, Vector2i(0, 2), false)).is_false()
	assert_bool(c.can_place(rifle, 0, Vector2i(-1, 0), false)).is_false()
	assert_bool(c.can_place(rifle, 1, Vector2i(0, 0), false)).is_false()


func test_item_cannot_be_in_two_places() -> void:
	var a := _container(Vector2i(4, 4))
	var b := _container(Vector2i(4, 4))
	var box := ItemInstance.new(_box_def)
	assert_bool(a.place(box, 0, Vector2i.ZERO, false)).is_true()
	assert_bool(b.place(box, 0, Vector2i.ZERO, false)).is_false()
	assert_bool(a.remove(box)).is_true()
	assert_bool(b.place(box, 0, Vector2i.ZERO, false)).is_true()
	assert_object(box.location()).is_same(b)


func test_remove_frees_cells() -> void:
	var c := _container(Vector2i(4, 2))
	var rifle := ItemInstance.new(_rifle_def)
	c.place(rifle, 0, Vector2i.ZERO, false)
	assert_int(c.grids[0].free_cells()).is_equal(0)
	c.remove(rifle)
	assert_int(c.grids[0].free_cells()).is_equal(8)
	assert_object(rifle.location()).is_null()


func test_item_at_returns_occupant() -> void:
	var c := _container(Vector2i(5, 3))
	var rifle := ItemInstance.new(_rifle_def)
	c.place(rifle, 0, Vector2i(1, 1), false)
	assert_object(c.grids[0].item_at(Vector2i(4, 2))).is_same(rifle)
	assert_object(c.grids[0].item_at(Vector2i(0, 0))).is_null()


# --- Rotación ---

func test_rotation_swaps_footprint() -> void:
	var c := _container(Vector2i(2, 4))
	var rifle := ItemInstance.new(_rifle_def)
	assert_bool(c.can_place(rifle, 0, Vector2i.ZERO, false)).is_false()
	assert_bool(c.place(rifle, 0, Vector2i.ZERO, true)).is_true()
	assert_bool(c.locate(rifle).rotated as bool).is_true()


func test_non_rotatable_item_cannot_rotate() -> void:
	var c := _container(Vector2i(1, 3))
	var flat := ItemInstance.new(_flat_def)
	assert_bool(c.can_place(flat, 0, Vector2i.ZERO, true)).is_false()
	assert_bool(c.insert_anywhere(flat)).is_false()


func test_rotate_in_place_ignores_own_cells() -> void:
	var c := _container(Vector2i(4, 4))
	var rifle := ItemInstance.new(_rifle_def)
	c.place(rifle, 0, Vector2i.ZERO, false)
	# Rotado ocupa (0,0)-(1,3): solapa consigo mismo, pero se permite.
	assert_bool(c.can_place(rifle, 0, Vector2i.ZERO, true)).is_true()


func test_insert_anywhere_uses_rotation_when_needed() -> void:
	var c := _container(Vector2i(2, 4))
	var rifle := ItemInstance.new(_rifle_def)
	assert_bool(c.insert_anywhere(rifle)).is_true()
	assert_bool(c.locate(rifle).rotated as bool).is_true()


# --- Anidado ---

func test_nested_container_keeps_contents() -> void:
	var stash := _container(Vector2i(6, 6))
	var backpack := ItemInstance.new(_backpack_def)
	var box := ItemInstance.new(_box_def)
	assert_bool(backpack.contents.insert_anywhere(box)).is_true()
	assert_bool(stash.insert_anywhere(backpack)).is_true()
	assert_object(stash.find(box.uuid)).is_same(box)
	stash.remove(backpack)
	assert_object(backpack.contents.find(box.uuid)).is_same(box)


func test_container_cannot_go_inside_itself() -> void:
	var backpack := ItemInstance.new(_backpack_def)
	assert_bool(backpack.contents.insert_anywhere(backpack)).is_false()
	assert_bool(backpack.contents.can_place(backpack, 0, Vector2i.ZERO, false)).is_false()


func test_container_cannot_go_inside_descendant() -> void:
	var backpack := ItemInstance.new(_backpack_def)
	var pouch := ItemInstance.new(_pouch_def)
	assert_bool(backpack.contents.insert_anywhere(pouch)).is_true()
	# La mochila no puede entrar en la riñonera que lleva dentro.
	assert_bool(pouch.contents.can_hold(backpack)).is_false()
	# Pero otra riñonera sí puede entrar en la primera.
	var other_pouch := ItemInstance.new(_pouch_def)
	assert_bool(pouch.contents.can_hold(other_pouch)).is_true()


func test_weight_includes_nested_contents() -> void:
	var backpack := ItemInstance.new(_backpack_def)
	var ammo := ItemInstance.new(_ammo_def, 30)
	backpack.contents.insert_anywhere(ammo)
	assert_float(backpack.weight_kg()).is_equal_approx(1.0 + 30.0, 0.0001)


# --- Stacks ---

func test_merge_respects_max_stack() -> void:
	var a := ItemInstance.new(_ammo_def, 50)
	var b := ItemInstance.new(_ammo_def, 30)
	assert_int(a.merge_from(b)).is_equal(10)
	assert_int(a.quantity).is_equal(60)
	assert_int(b.quantity).is_equal(20)


func test_cannot_merge_different_or_unstackable() -> void:
	var ammo := ItemInstance.new(_ammo_def, 10)
	var box_a := ItemInstance.new(_box_def)
	var box_b := ItemInstance.new(_box_def)
	assert_bool(ammo.can_stack_with(box_a)).is_false()
	assert_bool(box_a.can_stack_with(box_b)).is_false()
	assert_bool(ammo.can_stack_with(ammo)).is_false()


func test_split_creates_new_instance() -> void:
	var ammo := ItemInstance.new(_ammo_def, 40)
	var part: ItemInstance = ammo.split(15)
	assert_int(ammo.quantity).is_equal(25)
	assert_int(part.quantity).is_equal(15)
	assert_str(String(part.uuid)).is_not_equal(String(ammo.uuid))
	assert_object(ammo.split(0)).is_null()
	assert_object(ammo.split(25)).is_null()


func test_merge_into_existing_stacks_in_container() -> void:
	var c := _container(Vector2i(2, 1))
	var a := ItemInstance.new(_ammo_def, 55)
	var b := ItemInstance.new(_ammo_def, 20)
	c.insert_anywhere(a)
	c.insert_anywhere(b)
	var incoming := ItemInstance.new(_ammo_def, 50)
	assert_int(c.merge_into_stacks(incoming)).is_equal(5)
	assert_int(c.count_ammo(&"ammo")).is_equal(0)


func test_quantity_is_clamped_to_max_stack() -> void:
	assert_int(ItemInstance.new(_ammo_def, 500).quantity).is_equal(60)
	assert_int(ItemInstance.new(_box_def, 3).quantity).is_equal(1)


func test_uuids_are_unique() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for i: int in 100:
		var item := ItemInstance.new(_box_def)
		assert_bool(seen.has(item.uuid)).is_false()
		seen[item.uuid] = true
