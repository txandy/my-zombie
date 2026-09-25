extends Node3D
## Escena del mundo generado: arranca una sesión single player (host sin clientes),
## genera el mundo desde la seed, lo construye y coloca al jugador.
##
## Seed: la de `world_seed`; si es 0, `--seed=N` en la línea de comandos
## (godot --path . -- --seed=123); si tampoco hay, una aleatoria.

@export var settings: WorldGenSettings
@export var world_seed: int = 0

@onready var _builder: WorldBuilder = $WorldBuilder
@onready var _player: Player = $Player


func _ready() -> void:
	NetManager.start_single_player()
	var chosen_seed: int = _resolve_seed()
	GameState.start_session(chosen_seed)

	var start: int = Time.get_ticks_msec()
	var data: WorldData = WorldGenerator.generate(chosen_seed, settings)
	var generated: int = Time.get_ticks_msec()
	_builder.build(data, settings)
	var built: int = Time.get_ticks_msec()
	print("Mundo seed=%d · generación %d ms · construcción %d ms · hash %s" % [
			chosen_seed, generated - start, built - generated, data.compute_hash().left(12)])

	_player.global_position = spawn_position(data, settings)
	_player.spawn_point = _player.global_position


func _resolve_seed() -> int:
	if world_seed != 0:
		return world_seed
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return GameState.random_world_seed()


## Provisional hasta la fase 9 (spawns): delante de la entrada del primer POI de tier 1
## o, si no hay, en el centro del mapa.
static func spawn_position(data: WorldData, settings: WorldGenSettings) -> Vector3:
	for poi: PoiPlacement in data.pois:
		var def: PoiDefinition = settings.poi_definitions[poi.definition_index]
		if def.tier == 1:
			var front := Vector3(0.0, 0.0, -(def.footprint_m.y * 0.5 + 4.0))
			var spot: Vector3 = poi.position + front.rotated(Vector3.UP, poi.rotation_steps * PI * 0.5)
			return Vector3(spot.x, _height_near(data, spot) + 1.0, spot.z)
	var center: float = data.resolution * data.cell_size_m * 0.5
	var mid := Vector3(center, 0.0, center)
	return Vector3(center, maxf(_height_near(data, mid), 0.0) + 2.0, center)


static func _height_near(data: WorldData, point: Vector3) -> float:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.height_at(x, z)
