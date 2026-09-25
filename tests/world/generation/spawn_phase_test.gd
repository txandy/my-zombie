# Tests de la fase 9 (spawns): aparición del jugador y campamentos de NPCs.
extends GdUnitTestSuite

const M1_SETTINGS_PATH: String = "res://data/world/m1_world_gen_settings.tres"

var _settings: WorldGenSettings


func before() -> void:
	_settings = load(M1_SETTINGS_PATH) as WorldGenSettings


func test_player_spawns_on_land() -> void:
	for world_seed: int in [1, 2, 3]:
		var data: WorldData = WorldGenerator.generate(world_seed, _settings)
		assert_float(data.spawns.player_spawn.y).is_greater(1.0)


func test_camps_are_far_from_player_and_at_pois() -> void:
	for world_seed: int in [1, 2, 3, 12345]:
		var data: WorldData = WorldGenerator.generate(world_seed, _settings)
		assert_int(data.spawns.camps.size()).is_between(1, _settings.npc_camp_count)
		for camp: SpawnData.Camp in data.spawns.camps:
			assert_float(camp.position.distance_to(data.spawns.player_spawn)).is_greater_equal(_settings.npc_camp_min_distance_m)
			assert_int(camp.poi_index).is_greater_equal(0)
			var archetype: NpcArchetype = _settings.npc_archetypes[camp.archetype_index]
			assert_int(camp.members).is_between(archetype.squad_min, archetype.squad_max)


func test_camps_use_distinct_pois() -> void:
	var data: WorldData = WorldGenerator.generate(7, _settings)
	var used: Array[int] = []
	for camp: SpawnData.Camp in data.spawns.camps:
		assert_bool(used.has(camp.poi_index)).is_false()
		used.append(camp.poi_index)


func test_spawns_are_deterministic() -> void:
	var a: WorldData = WorldGenerator.generate(99, _settings)
	var b: WorldData = WorldGenerator.generate(99, _settings)
	assert_array(Array(a.spawns.to_bytes())).is_equal(Array(b.spawns.to_bytes()))
