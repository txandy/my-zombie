class_name ZombieDirector
extends Node3D
## Población de zombis alrededor de los jugadores (GDD §4.5, §11.1). Solo en el host.
## - Mantiene hasta N zombis activos (más de noche) en puntos de spawn entre una distancia
##   mínima y máxima de algún jugador, y retira los que quedan lejos de todos.
## - Las noches de horda lanza oleadas dirigidas a la posición de los jugadores, que
##   escalan con el día y con el número de jugadores.
## El límite de activos respeta el objetivo de rendimiento (AGENTS.md §6: 50 zombis).

@export var zombie_scene: PackedScene
@export var cycle: DayNightCycle

@export_group("Población")
@export var max_active_day: int = 10
@export var max_active_night: int = 25
@export var spawn_min_distance_m: float = 45.0
@export var spawn_max_distance_m: float = 130.0
@export var despawn_distance_m: float = 200.0
@export var spawn_interval_s: float = 2.0

@export_group("Hordas")
@export var wave_size_base: int = 8
## Zombis extra por oleada por cada horda anterior (escala con el día).
@export var wave_growth_per_horde: int = 4
## Fracción extra por cada jugador adicional.
@export var extra_player_factor: float = 0.5
@export var waves_per_horde: int = 4
@export var wave_interval_s: float = 45.0
@export var horde_spawn_distance_m: float = 70.0
## Máximo absoluto de zombis (población + horda).
@export var hard_cap: int = 50

## Puntos de spawn (de SpawnData.zombie_points).
var spawn_points := PackedVector3Array()
## Oleadas que faltan de la horda en curso.
var horde_waves_left: int = 0

var _spawn_timer: float = 0.0
var _wave_timer: float = 0.0
var _serial: int = 0


func _ready() -> void:
	EventBus.night_changed.connect(_on_night_changed)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval_s
		maintain_population()
	if horde_waves_left > 0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = wave_interval_s
			spawn_wave()


func active_zombies() -> Array[Zombie]:
	var result: Array[Zombie] = []
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		var zombie := node as Zombie
		if zombie != null and zombie.state != Zombie.State.DEAD:
			result.append(zombie)
	return result


func max_active() -> int:
	return max_active_night if GameState.is_night else max_active_day


## Retira los zombis lejanos y rellena hasta el máximo actual (uno por llamada).
func maintain_population() -> void:
	var players: Array[Node3D] = _players()
	if players.is_empty():
		return
	var active: Array[Zombie] = active_zombies()
	for zombie: Zombie in active:
		if zombie.horde_target == null and _nearest_player_distance(zombie.global_position, players) > despawn_distance_m:
			zombie.queue_free()
	if active.size() < mini(max_active(), hard_cap):
		var point: Variant = _pick_spawn_point(players)
		if point != null:
			spawn_zombie(point as Vector3)


func spawn_zombie(at: Vector3, horde_target: Node3D = null) -> Zombie:
	var zombie := zombie_scene.instantiate() as Zombie
	_serial += 1
	zombie.name = "Zombie%d" % _serial
	zombie.position = at + Vector3.UP * 0.3
	zombie.horde_target = horde_target
	add_child(zombie)
	return zombie


# --- Hordas ---

func _on_night_changed(is_night: bool) -> void:
	if is_night and cycle != null and cycle.is_horde_night(GameState.day):
		start_horde()


func start_horde() -> void:
	horde_waves_left = waves_per_horde
	_wave_timer = 0.0


## Tamaño de oleada: base + crecimiento por horda (día) y escala por jugadores (GDD §4.5).
func wave_size(day: int, player_count: int) -> int:
	var hordes_so_far: int = maxi(day / maxi(cycle.settings.horde_every_days if cycle != null else 7, 1) - 1, 0)
	var size: float = wave_size_base + wave_growth_per_horde * hordes_so_far
	return roundi(size * (1.0 + extra_player_factor * maxi(player_count - 1, 0)))


func spawn_wave() -> void:
	horde_waves_left -= 1
	var players: Array[Node3D] = _players()
	if players.is_empty():
		return
	var room: int = hard_cap - active_zombies().size()
	var count: int = mini(wave_size(GameState.day, players.size()), room)
	for i: int in count:
		var target: Node3D = players[i % players.size()]
		var angle: float = Ballistics.rng.randf() * TAU
		var at: Vector3 = target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * horde_spawn_distance_m
		spawn_zombie(at, target)


# --- Utilidades ---

func _players() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		if not Perception._is_dead(node):
			result.append(node as Node3D)
	return result


static func _nearest_player_distance(point: Vector3, players: Array[Node3D]) -> float:
	var nearest: float = INF
	for player: Node3D in players:
		nearest = minf(nearest, player.global_position.distance_to(point))
	return nearest


func _pick_spawn_point(players: Array[Node3D]) -> Variant:
	if spawn_points.is_empty():
		return null
	for attempt: int in 12:
		var point: Vector3 = spawn_points[Ballistics.rng.randi_range(0, spawn_points.size() - 1)]
		var distance: float = _nearest_player_distance(point, players)
		if distance >= spawn_min_distance_m and distance <= spawn_max_distance_m:
			# Dispersión alrededor del punto para que no aparezcan todos en el mismo sitio.
			return point + Vector3(Ballistics.rng.randf_range(-6, 6), 0.0, Ballistics.rng.randf_range(-6, 6))
	return null
