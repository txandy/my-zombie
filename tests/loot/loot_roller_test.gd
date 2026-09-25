# Tests de las tablas de loot (obligatorios, AGENTS.md §5): determinismo, tier, bioma,
# cantidades, contenedores vacíos y tiradas por tier.
extends GdUnitTestSuite

var _a: ItemDefinition
var _b: ItemDefinition
var _rare: ItemDefinition
var _desert_only: ItemDefinition


func _item(id: StringName, stack: int = 1) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.max_stack = stack
	return def


func _entry(def: ItemDefinition, weight: float, min_q: int = 1, max_q: int = 1, tier: int = 1,
		biomes: Array[StringName] = []) -> LootEntry:
	var entry := LootEntry.new()
	entry.item = def
	entry.weight = weight
	entry.min_quantity = min_q
	entry.max_quantity = max_q
	entry.min_tier = tier
	entry.biomes = biomes
	return entry


func _table(entries: Array[LootEntry], min_rolls: int, max_rolls: int, extra: int = 0, empty: float = 0.0) -> LootTable:
	var table := LootTable.new()
	table.entries = entries
	table.min_rolls = min_rolls
	table.max_rolls = max_rolls
	table.extra_rolls_per_tier = extra
	table.empty_chance = empty
	return table


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func before() -> void:
	_a = _item(&"a", 50)
	_b = _item(&"b")
	_rare = _item(&"rare")
	_desert_only = _item(&"desert")


func _summary(items: Array[ItemInstance]) -> String:
	var parts: PackedStringArray = []
	for item: ItemInstance in items:
		parts.append("%s×%d" % [item.definition.id, item.quantity])
	return ",".join(parts)


func test_same_seed_same_loot() -> void:
	var table := _table([_entry(_a, 3, 5, 20), _entry(_b, 1)], 2, 4)
	var first: String = _summary(LootRoller.roll(table, 1, &"", _rng(77)))
	var second: String = _summary(LootRoller.roll(table, 1, &"", _rng(77)))
	assert_str(first).is_equal(second)
	assert_str(first).is_not_empty()


func test_tier_gates_entries() -> void:
	var table := _table([_entry(_a, 1), _entry(_rare, 100, 1, 1, 3)], 3, 3)
	for s: int in 50:
		for item: ItemInstance in LootRoller.roll(table, 2, &"", _rng(s)):
			assert_str(String(item.definition.id)).is_not_equal("rare")
	var found_rare: bool = false
	for item: ItemInstance in LootRoller.roll(table, 3, &"", _rng(1)):
		found_rare = found_rare or item.definition == _rare
	assert_bool(found_rare).is_true()


func test_biome_filters_entries() -> void:
	var desert: Array[StringName] = [&"desert"]
	var table := _table([_entry(_a, 1), _entry(_desert_only, 100, 1, 1, 1, desert)], 3, 3)
	for s: int in 30:
		for item: ItemInstance in LootRoller.roll(table, 1, &"meadow", _rng(s)):
			assert_object(item.definition).is_not_same(_desert_only)


func test_quantities_within_bounds() -> void:
	var table := _table([_entry(_a, 1, 5, 20)], 5, 5)
	for s: int in 30:
		for item: ItemInstance in LootRoller.roll(table, 1, &"", _rng(s)):
			assert_int(item.quantity).is_between(5, 20)


func test_empty_chance_one_is_always_empty() -> void:
	var table := _table([_entry(_a, 1)], 3, 3, 0, 1.0)
	assert_array(LootRoller.roll(table, 4, &"", _rng(1))).is_empty()


func test_higher_tier_adds_rolls() -> void:
	var table := _table([_entry(_b, 1)], 2, 2, 1)
	assert_int(LootRoller.roll(table, 1, &"", _rng(1)).size()).is_equal(2)
	assert_int(LootRoller.roll(table, 3, &"", _rng(1)).size()).is_equal(4)


func test_weights_bias_distribution() -> void:
	var table := _table([_entry(_a, 9), _entry(_b, 1)], 1, 1)
	var a_count: int = 0
	var trials: int = 2000
	var rng := _rng(3)
	for i: int in trials:
		if LootRoller.roll(table, 1, &"", rng)[0].definition == _a:
			a_count += 1
	assert_float(a_count / float(trials)).is_equal_approx(0.9, 0.03)


func test_no_valid_entries_gives_nothing() -> void:
	var table := _table([_entry(_rare, 1, 1, 1, 4)], 3, 3)
	assert_array(LootRoller.roll(table, 1, &"", _rng(1))).is_empty()


func test_real_tables_load_and_roll() -> void:
	for path: String in ["fridge", "locker", "shelf", "medical_cabinet", "military_crate"]:
		var table := load("res://data/loot/%s.tres" % path) as LootTable
		assert_object(table).is_not_null()
		for s: int in 10:
			for item: ItemInstance in LootRoller.roll(table, 2, &"meadow", _rng(s)):
				assert_object(item.definition).is_not_null()
