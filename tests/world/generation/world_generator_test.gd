# Tests de determinismo y estructura del pipeline de generación (GDD §4.2, AGENTS.md §1.2).
extends GdUnitTestSuite

const FIXTURE_PATH: String = "res://tests/world/generation/fixtures/hash_fixture_settings.tres"
const M1_SETTINGS_PATH: String = "res://data/world/m1_world_gen_settings.tres"
## Hash de referencia del fixture con la seed 12345. Si cambia, el mundo generado para
## todas las seeds ha cambiado: solo se actualiza a propósito y explicándolo en el commit.
const GOLDEN_SEED: int = 12345
const GOLDEN_HASH: String = "ad098b3d3c3dd72b7acac8e47a5442f48374b24e9c84795203c3a1e629fb4c75"

var _fixture: WorldGenSettings


func before() -> void:
	_fixture = load(FIXTURE_PATH) as WorldGenSettings


func test_phase_order_is_fixed() -> void:
	var names: Array[StringName] = []
	for phase: WorldGenPhase in WorldGenerator.create_phases():
		names.append(phase.phase_name())
	assert_array(names).is_equal([&"heightmap", &"climate", &"biomes"])


func test_same_seed_same_hash() -> void:
	var a: String = WorldGenerator.generate(777, _fixture).compute_hash()
	var b: String = WorldGenerator.generate(777, _fixture).compute_hash()
	assert_str(a).is_equal(b)


func test_different_seed_different_hash() -> void:
	var a: String = WorldGenerator.generate(777, _fixture).compute_hash()
	var b: String = WorldGenerator.generate(778, _fixture).compute_hash()
	assert_str(a).is_not_equal(b)


func test_golden_hash() -> void:
	var world_hash: String = WorldGenerator.generate(GOLDEN_SEED, _fixture).compute_hash()
	assert_str(world_hash).override_failure_message(
		"El hash del mundo ha cambiado: %s" % world_hash).is_equal(GOLDEN_HASH)


func test_does_not_touch_global_rng() -> void:
	seed(42)
	var expected: int = randi()
	seed(42)
	WorldGenerator.generate(777, _fixture)
	assert_int(randi()).is_equal(expected)


func test_grids_have_resolution_size() -> void:
	var data: WorldData = WorldGenerator.generate(1, _fixture)
	var cells: int = _fixture.resolution() * _fixture.resolution()
	assert_int(data.resolution).is_equal(_fixture.resolution())
	assert_int(data.heights.size()).is_equal(cells)
	assert_int(data.temperature.size()).is_equal(cells)
	assert_int(data.humidity.size()).is_equal(cells)
	assert_int(data.biomes.size()).is_equal(cells)


func test_map_edges_are_sea() -> void:
	var data: WorldData = WorldGenerator.generate(1, _fixture)
	var last: int = data.resolution - 1
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		assert_float(data.height_at(corner.x, corner.y)).is_less(0.0)


func test_climate_is_normalized() -> void:
	var data: WorldData = WorldGenerator.generate(1, _fixture)
	for i: int in range(0, data.temperature.size(), 97):
		assert_float(data.temperature[i]).is_between(0.0, 1.0)
		assert_float(data.humidity[i]).is_between(0.0, 1.0)


func test_pick_biome_uses_nearest_climate_and_height() -> void:
	var cold := BiomeDefinition.new()
	cold.climate_center = Vector2(0.1, 0.5)
	var hot := BiomeDefinition.new()
	hot.climate_center = Vector2(0.9, 0.5)
	hot.max_height = 50.0
	var biomes: Array[BiomeDefinition] = [cold, hot]
	assert_int(BiomePhase.pick_biome(biomes, Vector2(0.2, 0.5), 0.0)).is_equal(0)
	assert_int(BiomePhase.pick_biome(biomes, Vector2(0.8, 0.5), 0.0)).is_equal(1)
	# Por encima de max_height el bioma caliente no es válido.
	assert_int(BiomePhase.pick_biome(biomes, Vector2(0.8, 0.5), 100.0)).is_equal(0)


func test_m1_settings_produce_both_biomes() -> void:
	# Misma geografía que M1 muestreada cada 8 m para que el test sea rápido.
	var settings := (load(M1_SETTINGS_PATH) as WorldGenSettings).duplicate() as WorldGenSettings
	settings.cell_size_m = 8.0
	var counts: Array[int] = [0, 0]
	for world_seed: int in [1, 2, 3, 4, 5]:
		var data: WorldData = WorldGenerator.generate(world_seed, settings)
		for b: int in data.biomes:
			counts[b] += 1
	var total: float = counts[0] + counts[1]
	assert_float(counts[0] / total).override_failure_message("Poco bosque: %s" % [counts]).is_greater(0.15)
	assert_float(counts[1] / total).override_failure_message("Poca pradera: %s" % [counts]).is_greater(0.15)
