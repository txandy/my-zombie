class_name SpawnPhase
extends WorldGenPhase
## Fase 9: spawns (GDD §4.2). Zona de aparición del jugador (delante de un POI de tier 1,
## en el bioma más seguro) y campamentos de NPCs junto a POIs alejados del jugador.
## Puntos de spawn de zombis: en tierra, fuera de las huellas de los POIs y lejos del jugador.


func phase_name() -> StringName:
	return &"spawns"


func run(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	data.spawns = SpawnData.new()
	var spawn_poi: int = _player_poi(data, settings)
	data.spawns.player_spawn = _player_spawn(data, settings, spawn_poi)
	_place_camps(data, settings, rng, spawn_poi)
	_place_zombie_points(data, settings, rng)


# Primer POI de tier 1 en el bioma de menor dificultad (o -1).
func _player_poi(data: WorldData, settings: WorldGenSettings) -> int:
	var best: int = -1
	var best_difficulty: int = 99
	for i: int in data.pois.size():
		var poi: PoiPlacement = data.pois[i]
		if settings.poi_definitions[poi.definition_index].tier != 1:
			continue
		var difficulty: int = settings.biomes[_biome_index(data, poi.position)].difficulty
		if difficulty < best_difficulty:
			best = i
			best_difficulty = difficulty
	return best


func _player_spawn(data: WorldData, settings: WorldGenSettings, poi_index: int) -> Vector3:
	if poi_index < 0:
		var center: float = data.resolution * data.cell_size_m * 0.5
		return Vector3(center, maxf(_height(data, Vector3(center, 0, center)), 0.0) + 1.0, center)
	var poi: PoiPlacement = data.pois[poi_index]
	var def: PoiDefinition = settings.poi_definitions[poi.definition_index]
	var front := Vector3(0.0, 0.0, -(def.footprint_m.y * 0.5 + 4.0)).rotated(Vector3.UP, poi.rotation_steps * PI * 0.5)
	var spot: Vector3 = poi.position + front
	return Vector3(spot.x, _height(data, spot) + 1.0, spot.z)


func _place_camps(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator, spawn_poi: int) -> void:
	if settings.npc_archetypes.is_empty():
		return
	var order: Array[int] = []
	for i: int in data.pois.size():
		order.append(i)
	# Barajado determinista (Fisher-Yates con el RNG de la fase).
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	for poi_index: int in order:
		if data.spawns.camps.size() >= settings.npc_camp_count:
			break
		var poi: PoiPlacement = data.pois[poi_index]
		if poi_index == spawn_poi or poi.position.distance_to(data.spawns.player_spawn) < settings.npc_camp_min_distance_m:
			continue
		var archetype: int = _archetype_for(settings, settings.biomes[_biome_index(data, poi.position)].id, rng)
		if archetype < 0:
			continue
		var camp := SpawnData.Camp.new()
		camp.position = poi.position
		camp.archetype_index = archetype
		var def: NpcArchetype = settings.npc_archetypes[archetype]
		camp.members = rng.randi_range(def.squad_min, def.squad_max)
		camp.poi_index = poi_index
		data.spawns.camps.append(camp)


func _archetype_for(settings: WorldGenSettings, biome_id: StringName, rng: RandomNumberGenerator) -> int:
	var valid: Array[int] = []
	for i: int in settings.npc_archetypes.size():
		var biomes: Array[StringName] = settings.npc_archetypes[i].biomes
		if biomes.is_empty() or biomes.has(biome_id):
			valid.append(i)
	return valid[rng.randi_range(0, valid.size() - 1)] if not valid.is_empty() else -1


static func _biome_index(data: WorldData, point: Vector3) -> int:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.biomes[data.index(x, z)]


static func _height(data: WorldData, point: Vector3) -> float:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.height_at(x, z)


func _place_zombie_points(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	var size: float = (data.resolution - 1) * data.cell_size_m
	var attempts: int = settings.zombie_spawn_points * 10
	while data.spawns.zombie_points.size() < settings.zombie_spawn_points and attempts > 0:
		attempts -= 1
		var point := Vector3(rng.randf_range(0.0, size), 0.0, rng.randf_range(0.0, size))
		point.y = _height(data, point)
		if point.y < 1.0 or point.distance_to(data.spawns.player_spawn) < settings.zombie_min_distance_to_spawn_m:
			continue
		if _inside_poi(data, settings, point):
			continue
		data.spawns.zombie_points.append(point)


static func _inside_poi(data: WorldData, settings: WorldGenSettings, point: Vector3) -> bool:
	for poi: PoiPlacement in data.pois:
		var half: Vector2 = poi.rotated_footprint(settings.poi_definitions[poi.definition_index]) * 0.5 + Vector2.ONE * 2.0
		if absf(point.x - poi.position.x) <= half.x and absf(point.z - poi.position.z) <= half.y:
			return true
	return false
