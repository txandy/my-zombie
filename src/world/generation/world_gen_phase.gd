class_name WorldGenPhase
extends RefCounted
## Fase del pipeline de generación. Cada fase usa solo su propio RNG,
## ctx.rng(phase_name()), y nunca el RNG global.


## Nombre estable de la fase. Cambiarlo cambia el mundo generado (ADR 0001).
func phase_name() -> StringName:
	assert(false, "WorldGenPhase.phase_name() sin implementar")
	return &""


func run(_data: WorldData, _settings: WorldGenSettings, _rng: RandomNumberGenerator) -> void:
	assert(false, "WorldGenPhase.run() sin implementar")


## Crea un FastNoiseLite con seed tomada del RNG de la fase.
## FastNoiseLite usa seeds de 32 bits: se enmascara a 31 bits positivos.
static func make_noise(rng: RandomNumberGenerator, frequency: float,
		fractal: FastNoiseLite.FractalType, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = rng.randi() & 0x7FFFFFFF
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	return noise
