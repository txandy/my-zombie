class_name WorldGenerator
extends RefCounted
## Pipeline de generación del mundo (GDD §4.2). Ejecuta las fases en un orden fijo;
## cada una con su propio RNG derivado de la seed (ADR 0001).


## Fases en orden. Añadir, quitar o reordenar fases cambia el mundo generado.
static func create_phases() -> Array[WorldGenPhase]:
	return [
		HeightmapPhase.new(),
		ClimatePhase.new(),
		BiomePhase.new(),
		PoiPhase.new(),
		VegetationPhase.new(),
		SpawnPhase.new(),
	]


static func generate(world_seed: int, settings: WorldGenSettings) -> WorldData:
	var data := WorldData.new()
	data.world_seed = world_seed
	data.resolution = settings.resolution()
	data.cell_size_m = settings.cell_size_m
	for phase: WorldGenPhase in create_phases():
		var start: int = Time.get_ticks_msec()
		phase.run(data, settings, SeedUtil.make_rng(world_seed, phase.phase_name()))
		data.timings[phase.phase_name()] = Time.get_ticks_msec() - start
	return data
