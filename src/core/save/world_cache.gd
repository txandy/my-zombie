class_name WorldCache
## Caché en disco del mundo generado (GDD §4.2, §13): cargar una partida no lo regenera.
## Se guarda el WorldData completo (rejillas, POIs, vegetación, spawns) junto a su hash,
## que se comprueba al cargar.


static func to_dict(data: WorldData) -> Dictionary:
	var pois: Array = []
	for poi: PoiPlacement in data.pois:
		pois.append({"def": poi.definition_index, "pos": poi.position, "rot": poi.rotation_steps})
	var camps: Array = []
	for camp: SpawnData.Camp in data.spawns.camps:
		camps.append({"pos": camp.position, "arch": camp.archetype_index, "n": camp.members, "poi": camp.poi_index})
	return {
		"seed": data.world_seed, "resolution": data.resolution, "cell": data.cell_size_m,
		"heights": data.heights, "temperature": data.temperature, "humidity": data.humidity,
		"biomes": data.biomes, "pois": pois, "vegetation": data.vegetation,
		"spawns": {"player": data.spawns.player_spawn, "camps": camps, "zombies": data.spawns.zombie_points},
		"hash": data.compute_hash(),
	}


## Reconstruye el WorldData. Devuelve null si el hash no coincide (caché corrupta).
static func from_dict(d: Dictionary) -> WorldData:
	var data := WorldData.new()
	data.world_seed = int(d.seed)
	data.resolution = int(d.resolution)
	data.cell_size_m = float(d.cell)
	data.heights = d.heights
	data.temperature = d.temperature
	data.humidity = d.humidity
	data.biomes = d.biomes
	for p: Dictionary in d.pois:
		data.pois.append(PoiPlacement.new(int(p.def), p.pos as Vector3, int(p.rot)))
	for layer: PackedFloat32Array in d.vegetation:
		data.vegetation.append(layer)
	data.spawns = SpawnData.new()
	data.spawns.player_spawn = d.spawns.player
	for c: Dictionary in d.spawns.camps:
		var camp := SpawnData.Camp.new()
		camp.position = c.pos
		camp.archetype_index = int(c.arch)
		camp.members = int(c.n)
		camp.poi_index = int(c.poi)
		data.spawns.camps.append(camp)
	data.spawns.zombie_points = d.spawns.zombies
	if data.compute_hash() != String(d.hash):
		push_error("Caché del mundo corrupta: el hash no coincide")
		return null
	return data
