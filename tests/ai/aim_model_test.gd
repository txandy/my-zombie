# Tests del modelo de puntería (obligatorios, AGENTS.md §5): convergencia del error,
# tiempo de reacción, límites de headshot, factores de error, y una simulación del
# criterio de aceptación del GDD §11.2 con el perfil real del bandido.
extends GdUnitTestSuite

const PROFILE_PATH: String = "res://data/ai/bandit_profile.tres"
## Semiancho aproximado del tórax (m) para la simulación geométrica.
const THORAX_RADIUS_M: float = 0.2

var _profile: NPCCombatProfile


func before() -> void:
	_profile = load(PROFILE_PATH) as NPCCombatProfile


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _context(distance: float = 50.0) -> AimModel.Context:
	var context := AimModel.Context.new()
	context.distance_m = distance
	return context


func test_reaction_time_within_profile_range() -> void:
	for s: int in 50:
		var aim := AimModel.new(_profile)
		aim.on_target_acquired(_rng(s))
		assert_bool(aim.can_fire()).is_false()
		assert_float(aim.reaction_left()).is_between(_profile.reaction_time_min_s, _profile.reaction_time_max_s)


func test_can_fire_after_reaction() -> void:
	var aim := AimModel.new(_profile)
	aim.on_target_acquired(_rng(1))
	aim.update(_profile.reaction_time_max_s + 0.01, true)
	assert_bool(aim.can_fire()).is_true()


func test_reaction_does_not_advance_without_sight() -> void:
	var aim := AimModel.new(_profile)
	aim.on_target_acquired(_rng(1))
	aim.update(5.0, false)
	assert_bool(aim.can_fire()).is_false()


func test_spread_converges_monotonically_to_min() -> void:
	var aim := AimModel.new(_profile)
	var context := _context(0.0)
	var previous: float = aim.spread_deg(context)
	assert_float(previous).is_equal_approx(_profile.base_spread_deg, 0.0001)
	var steps: int = 20
	for i: int in steps:
		aim.update(_profile.aim_settle_time_s / steps, true)
		var current: float = aim.spread_deg(context)
		assert_float(current).is_less_equal(previous)
		previous = current
	assert_float(previous).is_equal_approx(_profile.min_spread_deg, 0.0001)


func test_losing_sight_unsettles_partially() -> void:
	var aim := AimModel.new(_profile)
	aim.update(_profile.aim_settle_time_s, true)
	aim.update(0.1, false)
	assert_float(aim.settle).is_equal_approx(1.0 - _profile.unsettle_on_lost_sight, 0.0001)
	# Solo se desasienta al perder la vista, no en cada tick sin ver.
	aim.update(0.1, false)
	assert_float(aim.settle).is_equal_approx(1.0 - _profile.unsettle_on_lost_sight, 0.0001)


func test_error_grows_with_distance_motion_suppression_and_injury() -> void:
	var aim := AimModel.new(_profile)
	aim.update(_profile.aim_settle_time_s, true)
	var base: float = aim.spread_deg(_context(10.0))
	assert_float(aim.spread_deg(_context(200.0))).is_greater(base)
	var moving := _context(10.0)
	moving.target_lateral_speed = 5.0
	assert_float(aim.spread_deg(moving)).is_greater(base)
	var self_moving := _context(10.0)
	self_moving.self_moving = true
	assert_float(aim.spread_deg(self_moving)).is_greater(base)
	var suppressed := _context(10.0)
	suppressed.suppression = 1.0
	assert_float(aim.spread_deg(suppressed)).is_greater(base)
	var injured := _context(10.0)
	injured.injury_multiplier = 2.0
	assert_float(aim.spread_deg(injured)).is_equal_approx(base * 2.0, 0.0001)


func test_headshot_chance_is_capped_and_grows_with_settle() -> void:
	var aim := AimModel.new(_profile)
	assert_float(aim.headshot_chance()).is_equal(0.0)
	aim.update(_profile.aim_settle_time_s * 0.5, true)
	var half: float = aim.headshot_chance()
	aim.update(_profile.aim_settle_time_s, true)
	assert_float(aim.headshot_chance()).is_greater(half)
	assert_float(aim.headshot_chance()).is_equal_approx(_profile.max_headshot_chance, 0.0001)


func test_headshot_rate_never_exceeds_cap() -> void:
	var aim := AimModel.new(_profile)
	aim.update(_profile.aim_settle_time_s, true)
	var rng := _rng(9)
	var heads: int = 0
	var trials: int = 4000
	for i: int in trials:
		if aim.pick_zone(rng) == BodyZones.Zone.HEAD:
			heads += 1
	assert_float(heads / float(trials)).is_less_equal(_profile.max_headshot_chance + 0.02)


func test_aim_direction_stays_within_spread() -> void:
	var aim := AimModel.new(_profile)
	var rng := _rng(4)
	var context := _context(50.0)
	var max_angle: float = deg_to_rad(aim.spread_deg(context))
	for i: int in 300:
		var dir: Vector3 = aim.aim_direction(Vector3.ZERO, Vector3(0, 0, -50), context, rng)
		assert_float(dir.angle_to(Vector3.FORWARD)).is_less_equal(max_angle + 0.00001)


# --- Criterio de aceptación (GDD §11.2), simulación geométrica ---

## Tiempo (s) hasta el primer impacto en el tórax de un objetivo a `distance`, o INF.
## Sigue la cadencia de ráfagas del perfil con el fusil del juego (600 RPM).
func _time_to_first_hit(distance: float, lateral_speed: float, rng: RandomNumberGenerator, max_time: float) -> float:
	var aim := AimModel.new(_profile)
	aim.on_target_acquired(rng)
	var context := _context(distance)
	context.target_lateral_speed = lateral_speed
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	var next_shot: float = 0.0
	var burst_left: int = 0
	while t < max_time:
		aim.update(dt, true)
		t += dt
		if not aim.can_fire() or t < next_shot:
			continue
		if burst_left <= 0:
			burst_left = rng.randi_range(_profile.burst_min, _profile.burst_max)
		var dir: Vector3 = aim.aim_direction(Vector3.ZERO, Vector3(0, 0, -distance), context, rng)
		var at_target: Vector3 = dir * (distance / -dir.z)
		# El objetivo se desplaza durante el vuelo; el NPC solo adelanta lead_fraction.
		var flight: float = distance / 715.0
		var offset := Vector2(at_target.x - lateral_speed * flight * (1.0 - _profile.lead_fraction), at_target.y)
		if offset.length() <= THORAX_RADIUS_M:
			return t
		burst_left -= 1
		next_shot = t + (60.0 / 600.0 if burst_left > 0 else _profile.burst_pause_s)
	return INF


func test_acceptance_exposed_still_target_at_50m() -> void:
	var rng := _rng(2024)
	var trials: int = 1500
	var within_2s: int = 0
	var before_1s: int = 0
	for i: int in trials:
		var t: float = _time_to_first_hit(50.0, 0.0, rng, 4.0)
		if t <= 2.0:
			within_2s += 1
		if t < 1.0:
			before_1s += 1
	# Casi siempre le dan en 2 s, pero rara vez antes de 1 s (no es un aimbot).
	assert_float(within_2s / float(trials)).override_failure_message(
		"Impactos en ≤2 s: %.2f" % (within_2s / float(trials))).is_greater_equal(0.8)
	assert_float(before_1s / float(trials)).override_failure_message(
		"Impactos en <1 s: %.2f" % (before_1s / float(trials))).is_less_equal(0.3)


func test_sprinting_target_is_much_harder_to_hit() -> void:
	var rng := _rng(99)
	var trials: int = 1500
	var still: int = 0
	var sprinting: int = 0
	for i: int in trials:
		if _time_to_first_hit(50.0, 0.0, rng, 2.0) <= 2.0:
			still += 1
		if _time_to_first_hit(50.0, 6.0, rng, 2.0) <= 2.0:
			sprinting += 1
	assert_float(sprinting / float(trials)).override_failure_message(
		"Quieto %.2f vs esprintando %.2f" % [still / float(trials), sprinting / float(trials)]
	).is_less(still / float(trials) * 0.6)
