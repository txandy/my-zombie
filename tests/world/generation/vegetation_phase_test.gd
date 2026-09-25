# Tests de la fase 8: la vegetación respeta agua, POIs y densidad por bioma.
extends GdUnitTestSuite

const FIXTURE_PATH: String = "res://tests/world/generation/fixtures/hash_fixture_settings.tres"
const STRIDE: int = VegetationPhase.STRIDE

var _settings: WorldGenSettings
var _data: WorldData


func before() -> void:
	_settings = load(FIXTURE_PATH) as WorldGenSettings
	_data = WorldGenerator.generate(12345, _settings)


func test_one_list_per_layer() -> void:
	assert_int(_data.vegetation.size()).is_equal(_settings.vegetation_layers.size())
	for layer: PackedFloat32Array in _data.vegetation:
		assert_int(layer.size() % STRIDE).is_equal(0)


func test_places_vegetation() -> void:
	var total: int = 0
	for layer: PackedFloat32Array in _data.vegetation:
		total += layer.size() / STRIDE
	assert_int(total).is_greater(0)


func test_no_vegetation_in_water_or_below_min_height() -> void:
	for l: int in _data.vegetation.size():
		var layer_def: VegetationLayer = _settings.vegetation_layers[l]
		var instances: PackedFloat32Array = _data.vegetation[l]
		for i: int in range(0, instances.size(), STRIDE):
			assert_float(instances[i + 1]).is_greater_equal(layer_def.min_height)


func test_no_vegetation_on_poi_footprints() -> void:
	for poi: PoiPlacement in _data.pois:
		var half: Vector2 = poi.rotated_footprint(_settings.poi_definitions[poi.definition_index]) * 0.5
		var rect := Rect2(Vector2(poi.position.x, poi.position.z) - half, half * 2.0)
		for instances: PackedFloat32Array in _data.vegetation:
			for i: int in range(0, instances.size(), STRIDE):
				assert_bool(rect.has_point(Vector2(instances[i], instances[i + 2]))).is_false()


func test_scale_within_layer_range() -> void:
	for l: int in _data.vegetation.size():
		var layer_def: VegetationLayer = _settings.vegetation_layers[l]
		var instances: PackedFloat32Array = _data.vegetation[l]
		for i: int in range(0, instances.size(), STRIDE):
			assert_float(instances[i + 4]).is_between(layer_def.min_scale - 0.0001, layer_def.max_scale + 0.0001)


func test_forest_has_denser_pines_than_meadow() -> void:
	var pine: int = _layer_index(&"pine")
	var per_biome: Dictionary[StringName, int] = {}
	var instances: PackedFloat32Array = _data.vegetation[pine]
	for i: int in range(0, instances.size(), STRIDE):
		var x: int = roundi(instances[i] / _data.cell_size_m)
		var z: int = roundi(instances[i + 2] / _data.cell_size_m)
		var biome_id: StringName = _settings.biomes[_data.biomes[_data.index(x, z)]].id
		per_biome[biome_id] = per_biome.get(biome_id, 0) + 1
	var forest_cells: int = _count_cells(&"temperate_forest")
	var meadow_cells: int = _count_cells(&"meadow")
	assert_int(forest_cells).is_greater(0)
	assert_int(meadow_cells).is_greater(0)
	var forest_density: float = per_biome.get(&"temperate_forest", 0) / float(forest_cells)
	var meadow_density: float = per_biome.get(&"meadow", 0) / float(meadow_cells)
	assert_float(forest_density).is_greater(meadow_density * 3.0)


func _layer_index(layer_id: StringName) -> int:
	for l: int in _settings.vegetation_layers.size():
		if _settings.vegetation_layers[l].id == layer_id:
			return l
	return -1


func _count_cells(biome_id: StringName) -> int:
	var count: int = 0
	for b: int in _data.biomes:
		if _settings.biomes[b].id == biome_id:
			count += 1
	return count
