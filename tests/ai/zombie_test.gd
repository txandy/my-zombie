# Tests de zombis: velocidad día/noche, olfato, oído, ataque e infección, reacción a
# disparos, muerte por disparo a la cabeza; director (población, retirada, hordas).
extends GdUnitTestSuite

const ZOMBIE_SCENE: String = "res://scenes/ai/zombie.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const Z := BodyZones.Zone

var _world: Node3D
var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	GameState.is_night = false
	Ballistics.clear()
	Ballistics.rng.seed = 11
	_world = auto_free(Node3D.new())
	add_child(_world)
	var floor_node := CSGBox3D.new()
	floor_node.size = Vector3(400, 1, 400)
	floor_node.use_collision = true
	_world.add_child(floor_node)
	floor_node.position.y = -0.5
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.respawn_time_s = 1000.0
	_player.global_position = Vector3(0, 0, 0)


func after_test() -> void:
	GameState.is_night = false
	Ballistics.clear()
	NetManager.close()


func _zombie(at: Vector3) -> Zombie:
	var zombie: Zombie = (load(ZOMBIE_SCENE) as PackedScene).instantiate() as Zombie
	_world.add_child(zombie)
	zombie.global_position = at
	zombie.home = at
	return zombie


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_basic_zombie_is_slow_by_day_and_fast_at_night() -> void:
	var zombie: Zombie = _zombie(Vector3(0, 0, -20))
	var day: float = zombie.chase_speed()
	GameState.is_night = true
	assert_float(zombie.chase_speed()).is_greater(day * 2.0)


func test_smells_player_through_a_wall() -> void:
	var wall := CSGBox3D.new()
	wall.size = Vector3(6, 3, 0.4)
	wall.use_collision = true
	_world.add_child(wall)
	wall.position = Vector3(0, 1.5, -3)
	var zombie: Zombie = _zombie(Vector3(0, 0, -6))
	zombie.rotation.y = PI
	await _ticks(45)
	assert_int(zombie.state).is_equal(Zombie.State.CHASE)


func test_hears_gunshot_and_investigates() -> void:
	var zombie: Zombie = _zombie(Vector3(0, 0, -150))
	await _ticks(2)
	EventBus.sound_emitted.emit(Vector3(0, 0, -20), 300.0, &"gunshot", _player)
	assert_int(zombie.state).is_equal(Zombie.State.INVESTIGATE)
	assert_vector(zombie.goal).is_equal(Vector3(0, 0, -20))


func test_attacks_and_can_infect() -> void:
	var zombie: Zombie = _zombie(Vector3(0, 0, -1.2))
	var profile := zombie.profile.duplicate() as ZombieProfile
	profile.infection_chance = 1.0
	zombie.profile = profile
	var before: float = _total(_player.health)
	await _ticks(120)
	assert_float(_total(_player.health)).is_less(before)
	assert_bool(_player.health.infected).is_true()


func test_antibiotics_cure_infection() -> void:
	_player.health.infect()
	var pills := ItemInstance.new(load("res://data/items/antibiotics.tres") as ItemDefinition)
	_player.inventory.give(pills)
	_player.inventory.request_use(pills.uuid)
	assert_bool(_player.health.infected).is_false()


func test_untreated_infection_eventually_hurts() -> void:
	_player.health.infect()
	var hours: float = _player.health.profile.infection_incubation_hours + 1.0
	var before: float = _player.health.hp(Z.THORAX)
	_player.health.tick(hours / GameState.game_hours_per_second)
	assert_float(_player.health.hp(Z.THORAX)).is_less(before)


func test_headshot_with_rifle_kills() -> void:
	var zombie: Zombie = _zombie(Vector3(0, 0, -10))
	zombie.set_physics_process(false)
	await _ticks(2)
	var ammo := load("res://data/combat/ammo/762x39_ps.tres") as AmmoDefinition
	(zombie.get_node("DamageReceiver") as DamageReceiver).receive_bullet(Z.HEAD, ammo, _player, Ballistics.rng)
	assert_int(zombie.state).is_equal(Zombie.State.DEAD)


func test_being_shot_makes_it_chase_the_shooter() -> void:
	var zombie: Zombie = _zombie(Vector3(0, 0, -60))
	await _ticks(2)
	var ammo := load("res://data/combat/ammo/9x19_pst.tres") as AmmoDefinition
	(zombie.get_node("DamageReceiver") as DamageReceiver).receive_bullet(Z.LEFT_LEG, ammo, _player, Ballistics.rng)
	assert_int(zombie.state).is_equal(Zombie.State.CHASE)
	assert_object(zombie.target).is_same(_player)


# --- Director ---

func _director() -> ZombieDirector:
	var director := ZombieDirector.new()
	director.zombie_scene = load(ZOMBIE_SCENE) as PackedScene
	var points := PackedVector3Array()
	for i: int in 40:
		var angle: float = TAU * i / 40.0
		points.append(Vector3(cos(angle), 0, sin(angle)) * 80.0)
	director.spawn_points = points
	_world.add_child(director)
	director.set_physics_process(false)
	return director


func test_director_respects_day_and_night_caps() -> void:
	var director: ZombieDirector = _director()
	for i: int in 60:
		director.maintain_population()
	assert_int(director.active_zombies().size()).is_equal(director.max_active_day)
	GameState.is_night = true
	for i: int in 60:
		director.maintain_population()
	assert_int(director.active_zombies().size()).is_equal(director.max_active_night)


func test_director_despawns_far_zombies() -> void:
	var director: ZombieDirector = _director()
	var far: Zombie = director.spawn_zombie(Vector3(0, 0, 500))
	director.maintain_population()
	await _ticks(1)
	assert_bool(is_instance_valid(far)).is_false()


func test_horde_waves_target_players_and_scale() -> void:
	var director: ZombieDirector = _director()
	assert_int(director.wave_size(7, 1)).is_equal(director.wave_size_base)
	assert_int(director.wave_size(14, 1)).is_greater(director.wave_size(7, 1))
	assert_int(director.wave_size(7, 2)).is_greater(director.wave_size(7, 1))
	director.start_horde()
	director.spawn_wave()
	var horde: Array[Zombie] = director.active_zombies()
	assert_int(horde.size()).is_equal(director.wave_size(GameState.day, 1))
	for zombie: Zombie in horde:
		assert_object(zombie.horde_target).is_same(_player)


func _total(health: HealthComponent) -> float:
	var total: float = 0.0
	for zone: BodyZones.Zone in BodyZones.ALL:
		total += health.hp(zone)
	return total
