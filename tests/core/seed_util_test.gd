# Tests de determinismo de la derivación de seeds (ADR 0001).
# Los valores esperados se han calculado con una implementación independiente
# (BigInt en Node.js). Si alguno cambia, el mundo generado para esa seed cambia:
# no actualices los vectores sin un ADR que lo justifique.
extends GdUnitTestSuite


func test_fnv1a_64_standard_vectors() -> void:
	assert_int(SeedUtil.fnv1a_64(PackedByteArray())).is_equal(-3750763034362895579)  # 0xcbf29ce484222325
	assert_int(SeedUtil.fnv1a_64("a".to_utf8_buffer())).is_equal(-5808556873153909620)  # 0xaf63dc4c8601ec8c
	assert_int(SeedUtil.fnv1a_64("foobar".to_utf8_buffer())).is_equal(-8821353812377114648)  # 0x85944171f73967e8


func test_derive_known_vectors() -> void:
	assert_int(SeedUtil.derive(0, &"heightmap")).is_equal(156301218614829238)
	assert_int(SeedUtil.derive(12345, &"heightmap")).is_equal(3199316325812853431)
	assert_int(SeedUtil.derive(12345, &"climate")).is_equal(3425909252279606219)
	assert_int(SeedUtil.derive(-1, &"biomes")).is_equal(821414303259257030)
	assert_int(SeedUtil.derive(42, &"ñandú")).is_equal(8680947098654008019)


func test_derive_int64_limits() -> void:
	assert_int(SeedUtil.derive(9223372036854775807, &"spawns")).is_equal(2629955922738093891)
	assert_int(SeedUtil.derive(-9223372036854775807 - 1, &"poi")).is_equal(-8658994248330798835)


func test_different_phases_give_different_seeds() -> void:
	var phases: Array[StringName] = [&"heightmap", &"climate", &"biomes", &"rivers", &"poi",
			&"roads", &"splatmap", &"vegetation", &"spawns"]
	var seen: Dictionary[int, StringName] = {}
	for phase: StringName in phases:
		var s: int = SeedUtil.derive(777, phase)
		assert_bool(seen.has(s)).override_failure_message(
			"Colisión entre '%s' y '%s'" % [phase, seen.get(s, &"")]).is_false()
		seen[s] = phase


func test_make_rng_is_reproducible() -> void:
	var a: RandomNumberGenerator = SeedUtil.make_rng(98765, &"vegetation")
	var b: RandomNumberGenerator = SeedUtil.make_rng(98765, &"vegetation")
	for i: int in 100:
		assert_int(a.randi()).is_equal(b.randi())


func test_make_rng_differs_per_phase() -> void:
	var a: RandomNumberGenerator = SeedUtil.make_rng(98765, &"vegetation")
	var b: RandomNumberGenerator = SeedUtil.make_rng(98765, &"spawns")
	var equal: int = 0
	for i: int in 100:
		if a.randi() == b.randi():
			equal += 1
	assert_int(equal).is_less(5)
