extends Node3D
## Escena del mundo generado: arranca una sesión single player (host sin clientes),
## genera el mundo desde la seed, lo construye, coloca al jugador y crea los campamentos
## de NPCs con su malla de navegación.
##
## Seed: la de `world_seed`; si es 0, `--seed=N` en la línea de comandos
## (godot --path . -- --seed=123); si tampoco hay, una aleatoria.

## Mitad del lado de la zona de navegación alrededor de cada campamento (m).
const CAMP_NAV_HALF_SIZE_M: float = 90.0

@export var settings: WorldGenSettings
@export var world_seed: int = 0

var data: WorldData

@onready var _builder: WorldBuilder = $WorldBuilder
@onready var _player: Player = $Player


func _ready() -> void:
	NetManager.start_single_player()
	var chosen_seed: int = _resolve_seed()
	GameState.start_session(chosen_seed)

	var start: int = Time.get_ticks_msec()
	data = WorldGenerator.generate(chosen_seed, settings)
	var generated: int = Time.get_ticks_msec()
	_builder.build(data, settings)
	var built: int = Time.get_ticks_msec()
	print("Mundo seed=%d · generación %d ms · construcción %d ms · hash %s" % [
			chosen_seed, generated - start, built - generated, data.compute_hash().left(12)])

	_player.global_position = data.spawns.player_spawn
	_player.spawn_point = _player.global_position
	_player.survival.climate_sampler = _climate_at
	_spawn_npcs()


func _resolve_seed() -> int:
	if world_seed != 0:
		return world_seed
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return GameState.random_world_seed()


func _spawn_npcs() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)
	var manager := AIManager.new()
	manager.name = "AIManager"
	add_child(manager)
	var registry := _builder.get_node(^"CoverRegistry") as CoverRegistry
	for i: int in data.spawns.camps.size():
		var camp: SpawnData.Camp = data.spawns.camps[i]
		NavRegionBuilder.bake(npcs, camp.position, CAMP_NAV_HALF_SIZE_M, _builder.terrain,
				_builder.get_node(^"POIs"), registry)
		CampSpawner.spawn_camp(npcs, camp, i, settings.npc_archetypes[camp.archetype_index], _height_at)
	manager.update_lods()
	_spawn_zombies()


func _height_at(point: Vector3) -> float:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.height_at(x, z)


## Temperatura normalizada (0-1) del clima generado en un punto (para la supervivencia).
func _climate_at(point: Vector3) -> float:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return data.temperature[data.index(x, z)]


func _spawn_zombies() -> void:
	var director := ZombieDirector.new()
	director.name = "Zombies"
	director.zombie_scene = load("res://scenes/ai/zombie.tscn") as PackedScene
	director.cycle = $DayNightCycle as DayNightCycle
	director.spawn_points = data.spawns.zombie_points
	add_child(director)
