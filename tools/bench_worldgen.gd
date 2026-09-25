extends SceneTree
## Mide el tiempo de generación del mundo con los ajustes reales.
## Uso: godot --headless --path . -s res://tools/bench_worldgen.gd -- [seed] [settings.tres]


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
	print("hash=%s" % data.compute_hash())
	quit()
