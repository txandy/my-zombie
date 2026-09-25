class_name BiomePhase
extends WorldGenPhase
## Fase 3: biomas. A cada celda se le asigna el bioma cuyo clima ideal está más cerca
## de su (temperatura, humedad), entre los que admiten su altura. GDD §4.2.
##
## Como el clima es de baja frecuencia, los bordes ya salen suaves. La mezcla de
## texturas en las transiciones se hace en el splatmap (fase 7).


func phase_name() -> StringName:
	return &"biomes"


func run(data: WorldData, settings: WorldGenSettings, _rng: RandomNumberGenerator) -> void:
	assert(not settings.biomes.is_empty(), "WorldGenSettings sin biomas")
	assert(settings.biomes.size() <= 255, "El mapa de biomas usa un byte por celda")
	var n: int = data.resolution
	data.biomes.resize(n * n)
	for i: int in n * n:
		var climate := Vector2(data.temperature[i], data.humidity[i])
		data.biomes[i] = pick_biome(settings.biomes, climate, data.heights[i])


## Índice del bioma más adecuado. Si ninguno admite la altura, se ignora esa restricción.
static func pick_biome(biomes: Array[BiomeDefinition], climate: Vector2, height: float) -> int:
	var best: int = -1
	var best_distance: float = INF
	var fallback: int = 0
	var fallback_distance: float = INF
	for b: int in biomes.size():
		var biome: BiomeDefinition = biomes[b]
		var d: float = climate.distance_squared_to(biome.climate_center)
		if d < fallback_distance:
			fallback_distance = d
			fallback = b
		if height >= biome.min_height and height <= biome.max_height and d < best_distance:
			best_distance = d
			best = b
	return best if best >= 0 else fallback
