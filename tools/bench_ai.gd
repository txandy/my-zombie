extends Node
## Benchmark de rendimiento (AGENTS.md §6): mundo generado, de noche, con 20 NPCs humanos
## y 50 zombis activos cerca del jugador. Imprime los FPS medios de cada segundo.
## Uso: godot --path . res://tools/bench_ai.tscn --disable-vsync -- --seed=12345

const HUMANS: int = 20
const ZOMBIES: int = 50
const MEASURE_S: float = 15.0

var _world: Node3D
var _elapsed: float = 0.0
var _samples: Array[float] = []
var _physics_ms: Array[float] = []


func _ready() -> void:
	_world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(_world)
	await get_tree().create_timer(1.0).timeout
	GameState.hour = 23.0
	var player := _world.get_node("Player") as Player
	player.health.profile = player.health.profile.duplicate() as HealthProfile
	player.health.profile.thorax_hp = 100000.0
	player.health.profile.head_hp = 100000.0
	player.health.reset()
	var director := _world.get_node("Zombies") as ZombieDirector
	director.set_physics_process(false)
	var bandit_scene := load("res://scenes/ai/bandit.tscn") as PackedScene
	var origin: Vector3 = player.global_position
	for i: int in ZOMBIES:
		var angle: float = TAU * i / ZOMBIES
		director.spawn_zombie(origin + Vector3(cos(angle), 2.0, sin(angle)) * (25.0 + (i % 5) * 8.0))
	var npcs := _world.get_node("NPCs")
	for i: int in HUMANS:
		var angle: float = TAU * i / HUMANS + 0.3
		var npc := bandit_scene.instantiate() as HumanNPC
		npc.name = "BenchBandit%d" % i
		npc.position = origin + Vector3(cos(angle), 2.0, sin(angle)) * (50.0 + (i % 4) * 15.0)
		npcs.add_child(npc)
	print("BENCH: %d NPCs humanos y %d zombis creados; midiendo %.0f s" % [HUMANS, ZOMBIES, MEASURE_S])


func _process(delta: float) -> void:
	if get_tree().get_nodes_in_group(&"zombie").is_empty():
		return
	_elapsed += delta
	if _elapsed > 3.0:
		_samples.append(Engine.get_frames_per_second())
		_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if _elapsed > 3.0 + MEASURE_S:
		_samples.sort()
		var total: float = 0.0
		for s: float in _samples:
			total += s
		_physics_ms.sort()
		print("BENCH tick de física (lógica + IA): mediana %.2f ms · p90 %.2f ms (presupuesto a 60 Hz: 16.7 ms)" % [
				_physics_ms[_physics_ms.size() / 2], _physics_ms[_physics_ms.size() * 9 / 10]])
		print("BENCH FPS medio %.0f · p10 %.0f · mín %.0f · zombis %d · humanos %d" % [total / _samples.size(),
				_samples[_samples.size() / 10], _samples[0], get_tree().get_nodes_in_group(&"zombie").size(),
				get_tree().get_nodes_in_group(&"npc").size()])
		get_tree().quit()
