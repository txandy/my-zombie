# Tests de la salud por zonas: daño, muerte, redistribución, estados y penalizaciones.
extends GdUnitTestSuite

const PROFILE_PATH: String = "res://data/combat/human_health_profile.tres"
const Z := BodyZones.Zone

var _profile: HealthProfile
var _health: HealthComponent
## RNG que nunca provoca estados (tiradas altas) para aislar el daño.
var _no_status: RandomNumberGenerator


func before_test() -> void:
	_profile = (load(PROFILE_PATH) as HealthProfile).duplicate() as HealthProfile
	_health = auto_free(HealthComponent.new())
	_health.profile = _profile
	add_child(_health)
	_health.set_physics_process(false)
	_no_status = RandomNumberGenerator.new()
	_profile.light_bleed_chance_per_damage = 0.0
	_profile.heavy_bleed_chance_per_damage = 0.0
	_profile.fracture_chance_per_damage = 0.0


func test_starts_with_gdd_hp() -> void:
	assert_float(_health.hp(Z.HEAD)).is_equal(35.0)
	assert_float(_health.hp(Z.THORAX)).is_equal(80.0)
	assert_float(_health.hp(Z.STOMACH)).is_equal(70.0)
	assert_float(_health.hp(Z.LEFT_ARM)).is_equal(60.0)
	assert_float(_health.hp(Z.RIGHT_LEG)).is_equal(65.0)


func test_damage_reduces_zone_only() -> void:
	_health.apply_damage(Z.STOMACH, 20.0, _no_status)
	assert_float(_health.hp(Z.STOMACH)).is_equal(50.0)
	assert_float(_health.hp(Z.THORAX)).is_equal(80.0)
	assert_bool(_health.is_dead).is_false()


func test_head_or_thorax_at_zero_kills() -> void:
	_health.apply_damage(Z.HEAD, 40.0, _no_status)
	assert_bool(_health.is_dead).is_true()
	_health.reset()
	_health.apply_damage(Z.THORAX, 79.0, _no_status)
	assert_bool(_health.is_dead).is_false()
	_health.apply_damage(Z.THORAX, 1.0, _no_status)
	assert_bool(_health.is_dead).is_true()


func test_no_damage_after_death() -> void:
	_health.apply_damage(Z.HEAD, 100.0, _no_status)
	_health.apply_damage(Z.LEFT_LEG, 10.0, _no_status)
	assert_float(_health.hp(Z.LEFT_LEG)).is_equal(65.0)


func test_destroyed_limb_redistributes_overflow() -> void:
	# Brazo de 60 HP recibe 90: sobran 30 × 0.7 = 21, repartidos entre las otras 6 zonas.
	_health.apply_damage(Z.LEFT_ARM, 90.0, _no_status)
	assert_bool(_health.is_destroyed(Z.LEFT_ARM)).is_true()
	var share: float = 30.0 * _profile.redistribution_factor / 6.0
	assert_float(_health.hp(Z.HEAD)).is_equal_approx(35.0 - share, 0.001)
	assert_float(_health.hp(Z.RIGHT_LEG)).is_equal_approx(65.0 - share, 0.001)
	assert_bool(_health.has_pain()).is_true()


func test_damage_to_destroyed_limb_can_kill() -> void:
	_health.apply_damage(Z.LEFT_LEG, 65.0, _no_status)
	for i: int in 30:
		_health.apply_damage(Z.LEFT_LEG, 40.0, _no_status)
	assert_bool(_health.is_dead).is_true()


func test_heavy_bleed_ticks_damage() -> void:
	_profile.heavy_bleed_chance_per_damage = 1.0
	_health.apply_damage(Z.STOMACH, 5.0, _no_status)
	assert_int(_health.bleeding(Z.STOMACH)).is_equal(HealthComponent.Bleed.HEAVY)
	_health.tick(10.0)
	assert_float(_health.hp(Z.STOMACH)).is_equal_approx(65.0 - _profile.heavy_bleed_dps * 10.0, 0.001)


func test_statuses_are_reproducible_with_same_seed() -> void:
	_profile.light_bleed_chance_per_damage = 0.02
	_profile.fracture_chance_per_damage = 0.02
	var results: Array[String] = []
	for attempt: int in 2:
		_health.reset()
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for zone: BodyZones.Zone in [Z.LEFT_ARM, Z.RIGHT_LEG, Z.STOMACH, Z.LEFT_LEG]:
			_health.apply_damage(zone, 20.0, rng)
		var summary: String = ""
		for zone: BodyZones.Zone in BodyZones.ALL:
			summary += "%d%d" % [_health.bleeding(zone), int(_health.is_fractured(zone))]
		results.append(summary)
	assert_str(results[0]).is_equal(results[1])


func test_fractures_only_on_limbs() -> void:
	_profile.fracture_chance_per_damage = 1.0
	_health.apply_damage(Z.STOMACH, 10.0, _no_status)
	_health.apply_damage(Z.RIGHT_ARM, 10.0, _no_status)
	assert_bool(_health.is_fractured(Z.STOMACH)).is_false()
	assert_bool(_health.is_fractured(Z.RIGHT_ARM)).is_true()
	assert_bool(_health.has_pain()).is_true()


func test_injury_penalties() -> void:
	assert_bool(_health.can_sprint()).is_true()
	_health.apply_damage(Z.RIGHT_LEG, 65.0, _no_status)
	assert_bool(_health.can_sprint()).is_false()
	assert_float(_health.movement_multiplier()).is_equal(_profile.leg_injury_speed_multiplier)
	assert_float(_health.spread_multiplier()).is_equal(1.0)
	_health.apply_damage(Z.LEFT_ARM, 60.0, _no_status)
	assert_float(_health.spread_multiplier()).is_equal(_profile.arm_injury_spread_multiplier)
	assert_float(_health.reload_multiplier()).is_equal(_profile.arm_injury_reload_multiplier)


func test_pain_wears_off() -> void:
	_profile.fracture_chance_per_damage = 1.0
	_health.apply_damage(Z.LEFT_ARM, 1.0, _no_status)
	_health.tick(_profile.pain_duration_s + 0.1)
	assert_bool(_health.has_pain()).is_false()


func test_client_cannot_apply_damage() -> void:
	NetManager.join("127.0.0.1", 24690)
	_health.apply_damage(Z.THORAX, 50.0, _no_status)
	NetManager.close()
	assert_float(_health.hp(Z.THORAX)).is_equal(80.0)
