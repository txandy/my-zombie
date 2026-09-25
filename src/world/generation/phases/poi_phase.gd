class_name PoiPhase
extends WorldGenPhase
## Fase 5: colocación de POIs por reglas y aplanado del terreno bajo su huella. GDD §4.2, §4.4.
##
## Se colocan primero los POIs de tier más alto (suelen ser más grandes y escasos).
## Cada intento elige posición y rotación con el RNG de la fase y comprueba, en orden:
## bioma, distancia a otros POIs, altura mínima y desnivel bajo la huella.


func phase_name() -> StringName:
	return &"poi"


func run(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	var biome_ids: Array[StringName] = []
	for biome: BiomeDefinition in settings.biomes:
		biome_ids.append(biome.id)
	for def_index: int in placement_order(settings.poi_definitions):
		var def: PoiDefinition = settings.poi_definitions[def_index]
		var placed: int = 0
		for attempt: int in def.max_count * settings.poi_attempts_per_instance:
			if placed >= def.max_count:
				break
			var candidate: PoiPlacement = _random_candidate(data, def, def_index, rng)
			if _is_valid(data, settings, biome_ids, candidate):
				_flatten(data, def, candidate)
				data.pois.append(candidate)
				placed += 1


## Índices de las definiciones ordenados por tier descendente y, a igualdad, por índice.
static func placement_order(definitions: Array[PoiDefinition]) -> Array[int]:
	var order: Array[int] = []
	for i: int in definitions.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if definitions[a].tier != definitions[b].tier:
			return definitions[a].tier > definitions[b].tier
		return a < b)
	return order


func _random_candidate(data: WorldData, def: PoiDefinition, def_index: int,
		rng: RandomNumberGenerator) -> PoiPlacement:
	var steps: int = rng.randi_range(0, 3)
	var candidate := PoiPlacement.new(def_index, Vector3.ZERO, steps)
	var half: Vector2 = candidate.rotated_footprint(def) * 0.5 + Vector2.ONE * def.flatten_margin_m
	var size: float = (data.resolution - 1) * data.cell_size_m
	candidate.position.x = rng.randf_range(half.x, size - half.x)
	candidate.position.z = rng.randf_range(half.y, size - half.y)
	return candidate


func _is_valid(data: WorldData, settings: WorldGenSettings, biome_ids: Array[StringName],
		candidate: PoiPlacement) -> bool:
	var def: PoiDefinition = settings.poi_definitions[candidate.definition_index]
	var cx: int = roundi(candidate.position.x / data.cell_size_m)
	var cz: int = roundi(candidate.position.z / data.cell_size_m)
	if not def.allowed_biomes.has(biome_ids[data.biomes[data.index(cx, cz)]]):
		return false
	if _too_close(data, settings, def, candidate):
		return false
	var stats: Vector3 = _footprint_height_stats(data, candidate.position,
			candidate.rotated_footprint(def))
	if stats.x < settings.poi_min_height or stats.y - stats.x > def.max_height_variation_m:
		return false
	candidate.position.y = stats.z
	return true


func _too_close(data: WorldData, settings: WorldGenSettings, def: PoiDefinition,
		candidate: PoiPlacement) -> bool:
	var center := Vector2(candidate.position.x, candidate.position.z)
	for other: PoiPlacement in data.pois:
		var other_def: PoiDefinition = settings.poi_definitions[other.definition_index]
		var required: float = (def.bounding_radius() + other_def.bounding_radius()
				+ maxf(def.min_distance_m, other_def.min_distance_m))
		if center.distance_squared_to(Vector2(other.position.x, other.position.z)) < required * required:
			return true
	return false


## (mínimo, máximo, media) de las alturas bajo la huella.
func _footprint_height_stats(data: WorldData, center: Vector3, footprint: Vector2) -> Vector3:
	var rect: Rect2i = _cell_rect(data, center, footprint * 0.5)
	var lo: float = INF
	var hi: float = -INF
	var total: float = 0.0
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var h: float = data.heights[data.index(x, z)]
			lo = minf(lo, h)
			hi = maxf(hi, h)
			total += h
	return Vector3(lo, hi, total / rect.get_area())


## Aplana la huella a la altura media y funde la franja de margen con el terreno.
func _flatten(data: WorldData, def: PoiDefinition, poi: PoiPlacement) -> void:
	var half: Vector2 = poi.rotated_footprint(def) * 0.5
	var margin: float = def.flatten_margin_m
	var rect: Rect2i = _cell_rect(data, poi.position, half + Vector2.ONE * margin)
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var dx: float = maxf(absf(x * data.cell_size_m - poi.position.x) - half.x, 0.0)
			var dz: float = maxf(absf(z * data.cell_size_m - poi.position.z) - half.y, 0.0)
			var outside: float = maxf(dx, dz)
			var weight: float = 1.0 if outside <= 0.0 else 1.0 - smoothstep(0.0, margin, outside)
			var i: int = data.index(x, z)
			data.heights[i] = lerpf(data.heights[i], poi.position.y, weight)


# Celdas cuyo punto cae dentro del rectángulo centrado en `center` con semiejes `half`.
func _cell_rect(data: WorldData, center: Vector3, half: Vector2) -> Rect2i:
	var cell: float = data.cell_size_m
	var x0: int = clampi(ceili((center.x - half.x) / cell), 0, data.resolution - 1)
	var z0: int = clampi(ceili((center.z - half.y) / cell), 0, data.resolution - 1)
	var x1: int = clampi(floori((center.x + half.x) / cell), 0, data.resolution - 1)
	var z1: int = clampi(floori((center.z + half.y) / cell), 0, data.resolution - 1)
	return Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)
