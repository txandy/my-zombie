class_name HeightmapPhase
extends WorldGenPhase
## Fase 1: heightmap. Forma continental + montañas (ridged) + detalle,
## con una máscara de costa en los bordes del mapa. GDD §4.2.

var _continental: FastNoiseLite
var _mountains: FastNoiseLite
var _detail: FastNoiseLite


func phase_name() -> StringName:
	return &"heightmap"


func run(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	# El orden de creación de los ruidos forma parte del determinismo: no lo cambies.
	_continental = make_noise(rng, settings.continental_frequency, FastNoiseLite.FRACTAL_FBM, 3)
	_mountains = make_noise(rng, settings.mountain_frequency, FastNoiseLite.FRACTAL_RIDGED, 4)
	_detail = make_noise(rng, settings.detail_frequency, FastNoiseLite.FRACTAL_FBM, 3)

	var n: int = data.resolution
	data.heights.resize(n * n)
	for z: int in n:
		for x: int in n:
			data.heights[z * n + x] = height_at(settings, x * data.cell_size_m, z * data.cell_size_m)


## Altura en el punto (wx, wz) del mapa, en metros.
func height_at(settings: WorldGenSettings, wx: float, wz: float) -> float:
	var continental: float = _continental.get_noise_2d(wx, wz) * 0.5 + 0.5
	var mountain_mask: float = smoothstep(settings.mountain_threshold, 1.0, continental)
	var ridges: float = _mountains.get_noise_2d(wx, wz) * 0.5 + 0.5
	var h: float = (settings.base_height
			+ continental * settings.continental_amplitude
			+ ridges * settings.mountain_amplitude * mountain_mask
			+ _detail.get_noise_2d(wx, wz) * settings.detail_amplitude)
	var size: float = settings.world_size_m
	var edge_distance: float = minf(minf(wx, wz), minf(size - wx, size - wz))
	var coast: float = smoothstep(0.0, settings.coast_width_m, edge_distance)
	return lerpf(settings.sea_floor_height, h, coast)
