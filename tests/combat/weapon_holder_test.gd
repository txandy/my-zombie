# Tests del WeaponHolder: munición, cadencia, recarga, cambio de arma, cuerpo a cuerpo,
# dispersión y autoridad. Y un test de integración con el Player disparando a un dummy.
extends GdUnitTestSuite

const DUMMY_SCENE: String = "res://scenes/combat/dummy.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const Z := BodyZones.Zone

var _world: Node3D
var _rifle: WeaponDefinition
var _pistol: WeaponDefinition
var _knife: WeaponDefinition


func before_test() -> void:
	_rifle = load("res://data/combat/weapons/assault_rifle.tres") as WeaponDefinition
	_pistol = load("res://data/combat/weapons/pistol.tres") as WeaponDefinition
	_knife = load("res://data/combat/weapons/knife.tres") as WeaponDefinition
	_world = auto_free(Node3D.new())
	add_child(_world)
	NetManager.start_single_player()
	Ballistics.clear()
	Ballistics.rng.seed = 42


func after_test() -> void:
	Ballistics.clear()
	NetManager.close()


func _holder(loadout: Array[WeaponDefinition]) -> WeaponHolder:
	var holder := WeaponHolder.new()
	holder.loadout = loadout
	_world.add_child(holder)
	return holder


func _add_dummy(at: Vector3) -> TargetDummy:
	var dummy: TargetDummy = (load(DUMMY_SCENE) as PackedScene).instantiate() as TargetDummy
	_world.add_child(dummy)
	dummy.global_position = at
	return dummy


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_fire_consumes_round_and_respects_rate() -> void:
	var holder: WeaponHolder = _holder([_rifle])
	holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
	holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
	assert_int(holder.current_rounds()).is_equal(_rifle.magazine_size - 1)
	await _ticks(ceili(_rifle.fire_interval_s() * Engine.physics_ticks_per_second) + 1)
	holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
	assert_int(holder.current_rounds()).is_equal(_rifle.magazine_size - 2)


func test_empty_magazine_does_not_fire_and_reload_refills() -> void:
	var holder: WeaponHolder = _holder([_pistol])
	holder.rounds[0] = 0
	holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
	assert_int(Ballistics.active_count()).is_equal(0)
	holder.request_reload()
	assert_bool(holder.is_reloading()).is_true()
	await _ticks(ceili(_pistol.reload_time_s * Engine.physics_ticks_per_second) + 2)
	assert_bool(holder.is_reloading()).is_false()
	assert_int(holder.current_rounds()).is_equal(_pistol.magazine_size)


func test_switch_weapon() -> void:
	var holder: WeaponHolder = _holder([_rifle, _pistol, _knife])
	holder.request_switch(2)
	assert_object(holder.current()).is_same(_knife)
	holder.request_switch(7)
	assert_object(holder.current()).is_same(_knife)


func test_knife_hits_dummy_in_range_only() -> void:
	var dummy: TargetDummy = _add_dummy(Vector3(0, 0, -1.2))
	var far_dummy: TargetDummy = _add_dummy(Vector3(3, 0, -5))
	var holder: WeaponHolder = _holder([_knife])
	await _ticks(2)
	holder.request_attack(Vector3(0, 1.3, 0), Vector3.FORWARD, false)
	assert_float(dummy.health.hp(Z.THORAX)).is_less(80.0)
	await _ticks(ceili(_knife.melee_interval_s * Engine.physics_ticks_per_second) + 1)
	holder.request_attack(Vector3(3, 1.3, 0), Vector3.FORWARD, false)
	assert_float(far_dummy.health.hp(Z.THORAX)).is_equal(80.0)


func test_spread_stays_inside_cone() -> void:
	var holder: WeaponHolder = _holder([_rifle])
	var angle: float = holder.spread_angle(_rifle, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 500:
		var dir: Vector3 = WeaponHolder.spread_direction(Vector3.FORWARD, angle, rng)
		assert_float(dir.angle_to(Vector3.FORWARD)).is_less_equal(angle + 0.00001)


func test_aiming_and_arm_injury_change_spread() -> void:
	var health := HealthComponent.new()
	health.profile = load("res://data/combat/human_health_profile.tres") as HealthProfile
	_world.add_child(health)
	var holder: WeaponHolder = _holder([_rifle])
	holder.health = health
	var aimed: float = holder.spread_angle(_rifle, true)
	assert_float(holder.spread_angle(_rifle, false)).is_equal_approx(aimed * _rifle.hip_spread_multiplier, 0.000001)
	health.apply_damage(Z.RIGHT_ARM, 60.0, RandomNumberGenerator.new())
	assert_float(holder.spread_angle(_rifle, true)).is_equal_approx(
			aimed * health.profile.arm_injury_spread_multiplier, 0.000001)


func test_dead_holder_cannot_attack() -> void:
	var health := HealthComponent.new()
	health.profile = load("res://data/combat/human_health_profile.tres") as HealthProfile
	_world.add_child(health)
	var holder: WeaponHolder = _holder([_rifle])
	holder.health = health
	health.apply_damage(Z.HEAD, 100.0, RandomNumberGenerator.new())
	holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
	assert_int(holder.current_rounds()).is_equal(_rifle.magazine_size)


func test_other_peer_cannot_use_holder() -> void:
	var holder: WeaponHolder = _holder([_rifle])
	holder.owner_peer_id = 7
	holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
	assert_int(holder.current_rounds()).is_equal(_rifle.magazine_size)


func test_player_shoots_dummy_with_input() -> void:
	_add_wall(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 0)
	var dummy: TargetDummy = _add_dummy(Vector3(0, 0, -8))
	await _ticks(5)
	# Pistola (semiautomática) apuntando al frente, a la altura del tórax del dummy.
	var switch := PlayerInputFrame.new()
	switch.weapon_slot = 1
	player.step(switch, 1.0 / 60.0)
	await _ticks(20)
	var shoot := PlayerInputFrame.new()
	shoot.fire_pressed = true
	shoot.aim = true
	shoot.look_delta = Vector2(0, atan2(1.65 - 1.3, 8.0))
	player.step(shoot, 1.0 / 60.0)
	await _ticks(10)
	assert_int(player.weapons.current_rounds()).is_equal(_pistol.magazine_size - 1)
	var total: float = 0.0
	for zone: BodyZones.Zone in BodyZones.ALL:
		total += dummy.health.hp(zone)
	assert_float(total).is_less(35.0 + 80.0 + 70.0 + 60.0 * 2 + 65.0 * 2)


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = center


func test_automatic_fire_keeps_nominal_rate() -> void:
	# 600 RPM a 60 Hz = un disparo cada 6 ticks exactos: en 60 ticks, 10 disparos.
	var holder: WeaponHolder = _holder([_rifle])
	var fired: Array[int] = [0]
	holder.shot_fired.connect(func(_w: WeaponDefinition) -> void: fired[0] += 1)
	for i: int in 60:
		holder.request_attack(Vector3.ZERO, Vector3.FORWARD, true)
		await get_tree().physics_frame
	assert_int(fired[0]).is_equal(10)
