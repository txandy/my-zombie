# Tests del cálculo de daño y armadura (ADR 0003).
extends GdUnitTestSuite

var _rules: CombatRules
var _ps: AmmoDefinition
var _hp: AmmoDefinition
var _vest_def: ArmorDefinition


func before() -> void:
	_rules = load("res://data/combat/combat_rules.tres") as CombatRules
	_ps = load("res://data/combat/ammo/762x39_ps.tres") as AmmoDefinition
	_hp = load("res://data/combat/ammo/762x39_hp.tres") as AmmoDefinition
	_vest_def = load("res://data/combat/armor/vest_class4.tres") as ArmorDefinition


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_vest_protects_thorax_and_stomach() -> void:
	var vest := ArmorInstance.new(_vest_def)
	assert_bool(vest.protects(BodyZones.Zone.THORAX)).is_true()
	assert_bool(vest.protects(BodyZones.Zone.STOMACH)).is_true()
	assert_bool(vest.protects(BodyZones.Zone.HEAD)).is_false()


func test_unarmored_hit_deals_full_damage() -> void:
	var result: DamageResolver.HitResult = DamageResolver.resolve_bullet(_ps, null, _rules, _rng())
	assert_float(result.damage).is_equal(_ps.damage)
	assert_bool(result.armor_hit).is_false()
	assert_bool(result.penetrated).is_true()


func test_armor_rating_scales_with_durability() -> void:
	var vest := ArmorInstance.new(_vest_def)
	assert_float(DamageResolver.armor_rating(vest, _rules)).is_equal(40.0)
	vest.durability = 0.0
	assert_float(DamageResolver.armor_rating(vest, _rules)).is_equal(40.0 * _rules.min_armor_effectiveness)


func test_penetration_chance_ramp() -> void:
	var vest := ArmorInstance.new(_vest_def)
	var spread: float = _rules.penetration_spread
	assert_float(DamageResolver.penetration_chance(40.0, vest, _rules)).is_equal_approx(0.5, 0.0001)
	assert_float(DamageResolver.penetration_chance(40.0 + spread, vest, _rules)).is_equal(1.0)
	assert_float(DamageResolver.penetration_chance(40.0 - spread, vest, _rules)).is_equal(0.0)
	assert_float(DamageResolver.penetration_chance(40.0 + spread * 0.5, vest, _rules)).is_equal_approx(0.75, 0.0001)


func test_low_pen_ammo_never_penetrates_class4_and_deals_blunt() -> void:
	# HP: penetración 12, muy por debajo de 40 - 15.
	for s: int in 20:
		var vest := ArmorInstance.new(_vest_def)
		var result: DamageResolver.HitResult = DamageResolver.resolve_bullet(_hp, vest, _rules, _rng(s))
		assert_bool(result.penetrated).is_false()
		assert_float(result.damage).is_equal_approx(_hp.damage * _vest_def.blunt_damage_factor, 0.0001)


func test_penetration_frequency_matches_chance() -> void:
	# PS (35) contra clase 4 nueva (40): probabilidad 0.5 - 5/30 ≈ 0.333.
	var expected: float = DamageResolver.penetration_chance(_ps.penetration, ArmorInstance.new(_vest_def), _rules)
	var rng := _rng(7)
	var penetrated: int = 0
	var trials: int = 4000
	for i: int in trials:
		var vest := ArmorInstance.new(_vest_def)
		if DamageResolver.resolve_bullet(_ps, vest, _rules, rng).penetrated:
			penetrated += 1
	assert_float(penetrated / float(trials)).is_equal_approx(expected, 0.03)


func test_worn_armor_is_penetrated_more_often() -> void:
	var fresh := ArmorInstance.new(_vest_def)
	var worn := ArmorInstance.new(_vest_def, _vest_def.max_durability * 0.2)
	assert_float(DamageResolver.penetration_chance(_ps.penetration, worn, _rules)).is_greater(
			DamageResolver.penetration_chance(_ps.penetration, fresh, _rules))


func test_durability_loss_is_capped_at_current_durability() -> void:
	var vest := ArmorInstance.new(_vest_def, 1.0)
	var result: DamageResolver.HitResult = DamageResolver.resolve_bullet(_ps, vest, _rules, _rng())
	assert_float(result.durability_loss).is_equal(1.0)


func test_always_consumes_one_roll() -> void:
	var a := _rng(3)
	var b := _rng(3)
	DamageResolver.resolve_bullet(_ps, null, _rules, a)
	DamageResolver.resolve_bullet(_ps, ArmorInstance.new(_vest_def), _rules, b)
	assert_float(a.randf()).is_equal(b.randf())
