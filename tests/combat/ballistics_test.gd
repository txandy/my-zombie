# Tests de balística con física real: impactos por zona, gravedad, exclusión y autoridad.
extends GdUnitTestSuite

const DUMMY_SCENE: String = "res://scenes/combat/dummy.tscn"
const Z := BodyZones.Zone

var _world: Node3D
var _ps: AmmoDefinition
var _hp: AmmoDefinition
var _impacts: Array[Dictionary] = []


func before_test() -> void:
	_ps = load("res://data/combat/ammo/762x39_ps.tres") as AmmoDefinition
	_hp = load("res://data/combat/ammo/762x39_hp.tres") as AmmoDefinition
	_world = auto_free(Node3D.new())
	add_child(_world)
	Ballistics.clear()
	Ballistics.rng.seed = 1234
	_impacts.clear()
	Ballistics.projectile_impacted.connect(_on_impact)


func after_test() -> void:
	Ballistics.projectile_impacted.disconnect(_on_impact)
	Ballistics.clear()
	NetManager.close()


func _on_impact(position: Vector3, _normal: Vector3, hitbox: Hitbox, _source: Node) -> void:
	_impacts.append({"position": position, "hitbox": hitbox})


func _add_dummy(at: Vector3, armor: Array[ArmorDefinition] = []) -> TargetDummy:
	var dummy: TargetDummy = (load(DUMMY_SCENE) as PackedScene).instantiate() as TargetDummy
	dummy.armor_set = armor
	_world.add_child(dummy)
	dummy.global_position = at
	return dummy


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = center


func _wait_ticks(ticks: int) -> void:
	for i: int in ticks:
		await get_tree().physics_frame


func test_headshot_kills_unarmored_dummy() -> void:
	var dummy: TargetDummy = _add_dummy(Vector3(0, 0, -10))
	await _wait_ticks(2)
	Ballistics.fire(Vector3(0, 1.625, 0), Vector3.FORWARD, _ps, null)
	await _wait_ticks(10)
	assert_int(_impacts.size()).is_equal(1)
	assert_int((_impacts[0].hitbox as Hitbox).zone).is_equal(Z.HEAD)
	assert_bool(dummy.health.is_dead).is_true()


func test_leg_shot_damages_only_leg() -> void:
	var dummy: TargetDummy = _add_dummy(Vector3(0, 0, -10))
	await _wait_ticks(2)
	Ballistics.fire(Vector3(-0.1, 0.4, 0), Vector3.FORWARD, _ps, null)
	await _wait_ticks(10)
	# Margen de 1 HP por si el impacto ha causado un sangrado durante la espera.
	assert_float(dummy.health.hp(Z.LEFT_LEG)).is_between(65.0 - _ps.damage - 1.0, 65.0 - _ps.damage + 0.001)
	assert_float(dummy.health.hp(Z.THORAX)).is_equal(80.0)


func test_gravity_drop_at_200m() -> void:
	_add_wall(Vector3(0, 0, -200), Vector3(20, 20, 1))
	await _wait_ticks(2)
	Ballistics.fire(Vector3(0, 2, 0), Vector3.FORWARD, _ps, null)
	await _wait_ticks(30)
	assert_int(_impacts.size()).is_equal(1)
	var hit: Vector3 = _impacts[0].position
	var t: float = 199.5 / _ps.muzzle_velocity_mps
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	assert_float(2.0 - hit.y).is_equal_approx(0.5 * gravity * t * t, 0.03)


func test_does_not_hit_own_hitboxes() -> void:
	var shooter: TargetDummy = _add_dummy(Vector3.ZERO)
	var target: TargetDummy = _add_dummy(Vector3(0, 0, -15))
	await _wait_ticks(2)
	var exclude: Array[RID] = shooter.receiver.hitbox_rids()
	# Sale desde dentro de la cabeza del tirador.
	Ballistics.fire(Vector3(0, 1.3, 0), Vector3.FORWARD, _ps, shooter, exclude)
	await _wait_ticks(10)
	assert_float(shooter.health.hp(Z.THORAX)).is_equal(80.0)
	assert_float(target.health.hp(Z.THORAX)).is_less(80.0)


func test_vest_stops_low_pen_round_with_blunt_damage() -> void:
	var vest := load("res://data/combat/armor/vest_class4.tres") as ArmorDefinition
	var dummy: TargetDummy = _add_dummy(Vector3(0, 0, -10), [vest])
	await _wait_ticks(2)
	Ballistics.fire(Vector3(0, 1.3, 0), Vector3.FORWARD, _hp, null)
	await _wait_ticks(10)
	var expected: float = 80.0 - _hp.damage * vest.blunt_damage_factor
	assert_float(dummy.health.hp(Z.THORAX)).is_between(expected - 1.0, expected + 0.001)
	assert_float(dummy.armor.piece_for(Z.THORAX).durability).is_less(vest.max_durability)


func test_bullet_expires_in_the_sky() -> void:
	Ballistics.fire(Vector3.ZERO, Vector3.UP, _ps, null)
	assert_int(Ballistics.active_count()).is_equal(1)
	await _wait_ticks(roundi(Ballistics.MAX_LIFETIME_S * Engine.physics_ticks_per_second) + 2)
	assert_int(Ballistics.active_count()).is_equal(0)
	assert_int(_impacts.size()).is_equal(0)


func test_client_cannot_fire() -> void:
	NetManager.join("127.0.0.1", 24691)
	Ballistics.fire(Vector3.ZERO, Vector3.FORWARD, _ps, null)
	assert_int(Ballistics.active_count()).is_equal(0)
