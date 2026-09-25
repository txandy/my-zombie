# Tests de la fase 5: los POIs colocados cumplen sus reglas y el terreno queda aplanado.
extends GdUnitTestSuite

const FIXTURE_PATH: String = "res://tests/world/generation/fixtures/hash_fixture_settings.tres"
const SEEDS: Array[int] = [1, 2, 3, 12345]

var _settings: WorldGenSettings
var _worlds: Array[WorldData] = []


func before() -> void:
	_settings = load(FIXTURE_PATH) as WorldGenSettings
	for world_seed: int in SEEDS:
		_worlds.append(WorldGenerator.generate(world_seed, _settings))


func _def(poi: PoiPlacement) -> PoiDefinition:
	return _settings.poi_definitions[poi.definition_index]


func test_places_some_pois() -> void:
	for data: WorldData in _worlds:
		assert_array(data.pois).is_not_empty()


func test_placement_order_is_tier_descending() -> void:
	var order: Array[int] = PoiPhase.placement_order(_settings.poi_definitions)
	for i: int in range(1, order.size()):
		assert_int(_settings.poi_definitions[order[i - 1]].tier).is_greater_equal(
				_settings.poi_definitions[order[i]].tier)


func test_max_count_is_respected() -> void:
	for data: WorldData in _worlds:
		var counts: Dictionary[int, int] = {}
		for poi: PoiPlacement in data.pois:
			counts[poi.definition_index] = counts.get(poi.definition_index, 0) + 1
		for def_index: int in counts:
			assert_int(counts[def_index]).is_less_equal(_settings.poi_definitions[def_index].max_count)


func test_pois_are_in_allowed_biomes() -> void:
	for data: WorldData in _worlds:
		for poi: PoiPlacement in data.pois:
			var cx: int = roundi(poi.position.x / data.cell_size_m)
			var cz: int = roundi(poi.position.z / data.cell_size_m)
			var biome_id: StringName = _settings.biomes[data.biomes[data.index(cx, cz)]].id
			assert_bool(_def(poi).allowed_biomes.has(biome_id)).is_true()


func test_pois_keep_min_distance() -> void:
	for data: WorldData in _worlds:
		for a: int in data.pois.size():
			for b: int in range(a + 1, data.pois.size()):
				var pa: PoiPlacement = data.pois[a]
				var pb: PoiPlacement = data.pois[b]
				var required: float = (_def(pa).bounding_radius() + _def(pb).bounding_radius()
						+ maxf(_def(pa).min_distance_m, _def(pb).min_distance_m))
				var distance: float = Vector2(pa.position.x, pa.position.z).distance_to(
						Vector2(pb.position.x, pb.position.z))
				assert_float(distance).is_greater_equal(required)


func test_footprint_is_flat_and_above_min_height() -> void:
	for data: WorldData in _worlds:
		for poi: PoiPlacement in data.pois:
			assert_float(poi.position.y).is_greater_equal(_settings.poi_min_height)
			var half: Vector2 = poi.rotated_footprint(_def(poi)) * 0.5
			for z: int in data.resolution:
				for x: int in data.resolution:
					var wx: float = x * data.cell_size_m
					var wz: float = z * data.cell_size_m
					if absf(wx - poi.position.x) <= half.x and absf(wz - poi.position.z) <= half.y:
						assert_float(data.height_at(x, z)).is_equal_approx(poi.position.y, 0.001)
