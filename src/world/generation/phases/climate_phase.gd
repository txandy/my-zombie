class_name ClimatePhase
extends WorldGenPhase
## Fase 2: clima. Temperatura y humedad de baja frecuencia; la temperatura
## baja con la altura. GDD §4.2.


func phase_name() -> StringName:
	return &"climate"


func run(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	var temperature_noise := make_noise(rng, settings.temperature_frequency, FastNoiseLite.FRACTAL_FBM, 2)
	var humidity_noise := make_noise(rng, settings.humidity_frequency, FastNoiseLite.FRACTAL_FBM, 2)

	var n: int = data.resolution
	data.temperature.resize(n * n)
	data.humidity.resize(n * n)
	for z: int in n:
		for x: int in n:
			var i: int = z * n + x
			var wx: float = x * data.cell_size_m
			var wz: float = z * data.cell_size_m
			var altitude: float = maxf(data.heights[i], 0.0)
			var t: float = (temperature_noise.get_noise_2d(wx, wz) * 0.5 + 0.5
					- altitude * settings.temperature_lapse_per_m)
			data.temperature[i] = clampf(t, 0.0, 1.0)
			data.humidity[i] = clampf(humidity_noise.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)
