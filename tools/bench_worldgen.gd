extends SceneTree
## Mide el tiempo de generación del mundo con los ajustes reales.
## Uso: godot --headless --path . -d --remote-debug tcp://127.0.0.1:0 -s res://tools/bench_worldgen.gd -- [seed] [settings.tres]
## (--remote-debug evita que un error de script deje Godot esperando en el depurador interactivo)


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var world_seed: int = int(args[0]) if args.size() > 0 else 12345
	var path: String = args[1] if args.size() > 1 else "res://data/world/m1_world_gen_settings.tres"
	var settings := load(path) as WorldGenSettings
	var start: int = Time.get_ticks_msec()
	var data: WorldData = WorldGenerator.generate(world_seed, settings)
	var total: int = Time.get_ticks_msec() - start
	print("seed=%d  %dx%d muestras  total=%d ms" % [world_seed, data.resolution, data.resolution, total])
	for phase: StringName in data.timings:
		print("  %-12s %6d ms" % [phase, data.timings[phase]])
	var poi_counts: Dictionary[StringName, int] = {}
	for poi: PoiPlacement in data.pois:
		var poi_id: StringName = settings.poi_definitions[poi.definition_index].id
		poi_counts[poi_id] = poi_counts.get(poi_id, 0) + 1
	print("pois=%s" % poi_counts)
	for l: int in data.vegetation.size():
		print("  veg %-10s %6d" % [settings.vegetation_layers[l].id, data.vegetation[l].size() / VegetationPhase.STRIDE])
	print("spawn=%s camps=%d" % [data.spawns.player_spawn.snapped(Vector3.ONE), data.spawns.camps.size()])
	print("hash=%s" % data.compute_hash())
	quit()
