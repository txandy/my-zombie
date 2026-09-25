# Tests de MovementComponent y de las reglas de postura (lógica pura, sin física).
extends GdUnitTestSuite

const PROFILE_PATH: String = "res://data/player/default_movement_profile.tres"
const DELTA: float = 1.0 / 60.0

var _profile: PlayerMovementProfile
var _movement: MovementComponent


func before_test() -> void:
	_profile = load(PROFILE_PATH) as PlayerMovementProfile
	_movement = auto_free(MovementComponent.new())
	_movement.setup(_profile)


func _frame(move: Vector2 = Vector2.ZERO, sprint: bool = false, jump: bool = false,
		lean: int = 0) -> PlayerInputFrame:
	var f := PlayerInputFrame.new()
	f.move = move
	f.sprint = sprint
	f.jump = jump
	f.lean = lean
	return f


func test_target_speed_per_posture() -> void:
	var p := PostureComponent.Posture
	assert_float(MovementComponent.target_speed(_profile, p.STANDING, false)).is_equal(_profile.walk_speed)
	assert_float(MovementComponent.target_speed(_profile, p.STANDING, true)).is_equal(_profile.sprint_speed)
	assert_float(MovementComponent.target_speed(_profile, p.CROUCHING, true)).is_equal(_profile.crouch_speed)
	assert_float(MovementComponent.target_speed(_profile, p.PRONE, false)).is_equal(_profile.prone_speed)


func test_profile_speeds_are_ordered() -> void:
	assert_float(_profile.sprint_speed).is_greater(_profile.walk_speed)
	assert_float(_profile.walk_speed).is_greater(_profile.crouch_speed)
	assert_float(_profile.crouch_speed).is_greater(_profile.prone_speed)
	assert_float(_profile.prone_height).is_greater_equal(_profile.capsule_radius * 2.0)


func test_sprint_only_forward_standing_and_not_leaning() -> void:
	var standing := PostureComponent.Posture.STANDING
	assert_bool(_movement.can_sprint(_frame(Vector2(0, 1), true), standing)).is_true()
	assert_bool(_movement.can_sprint(_frame(Vector2(0, -1), true), standing)).is_false()
	assert_bool(_movement.can_sprint(_frame(Vector2(1, 0), true), standing)).is_false()
	assert_bool(_movement.can_sprint(_frame(Vector2(0, 1), true, false, 1), standing)).is_false()
	assert_bool(_movement.can_sprint(_frame(Vector2(0, 1), true),
			PostureComponent.Posture.CROUCHING)).is_false()


func test_sprint_blocked_by_stamina_hook() -> void:
	_movement.sprint_allowed = false
	assert_bool(_movement.can_sprint(_frame(Vector2(0, 1), true),
			PostureComponent.Posture.STANDING)).is_false()


func test_forward_is_negative_z_and_accelerates() -> void:
	var v: Vector3 = _movement.compute_velocity(Vector3.ZERO, _frame(Vector2(0, 1)), Basis.IDENTITY,
			PostureComponent.Posture.STANDING, true, false, DELTA)
	assert_float(v.z).is_less(0.0)
	assert_float(absf(v.z)).is_equal_approx(_profile.acceleration * DELTA, 0.0001)


func test_speed_is_capped() -> void:
	var v := Vector3.ZERO
	for i: int in 120:
		v = _movement.compute_velocity(v, _frame(Vector2(0, 1)), Basis.IDENTITY,
				PostureComponent.Posture.STANDING, true, false, DELTA)
	assert_float(Vector2(v.x, v.z).length()).is_equal_approx(_profile.walk_speed, 0.001)


func test_gravity_only_in_air() -> void:
	var ground: Vector3 = _movement.compute_velocity(Vector3.ZERO, _frame(), Basis.IDENTITY,
			PostureComponent.Posture.STANDING, true, false, DELTA)
	var air: Vector3 = _movement.compute_velocity(Vector3.ZERO, _frame(), Basis.IDENTITY,
			PostureComponent.Posture.STANDING, false, false, DELTA)
	assert_float(ground.y).is_equal(0.0)
	assert_float(air.y).is_less(0.0)


func test_jump_rules() -> void:
	var jump := _frame(Vector2.ZERO, false, true)
	var standing := PostureComponent.Posture.STANDING
	var v: Vector3 = _movement.compute_velocity(Vector3.ZERO, jump, Basis.IDENTITY, standing, true, false, DELTA)
	assert_float(v.y).is_equal(_profile.jump_velocity)
	# En el aire no se salta.
	v = _movement.compute_velocity(Vector3.ZERO, jump, Basis.IDENTITY, standing, false, false, DELTA)
	assert_float(v.y).is_less(0.0)
	# El salto que te levanta de agachado no salta.
	v = _movement.compute_velocity(Vector3.ZERO, jump, Basis.IDENTITY, standing, true, true, DELTA)
	assert_float(v.y).is_equal(0.0)


func test_posture_requests() -> void:
	var p := PostureComponent.Posture
	var crouch := PlayerInputFrame.new()
	crouch.crouch_toggled = true
	var prone := PlayerInputFrame.new()
	prone.prone_toggled = true
	var jump := _frame(Vector2.ZERO, false, true)
	assert_int(PostureComponent.resolve_request(p.STANDING, crouch)).is_equal(p.CROUCHING)
	assert_int(PostureComponent.resolve_request(p.CROUCHING, crouch)).is_equal(p.STANDING)
	assert_int(PostureComponent.resolve_request(p.STANDING, prone)).is_equal(p.PRONE)
	assert_int(PostureComponent.resolve_request(p.PRONE, prone)).is_equal(p.STANDING)
	assert_int(PostureComponent.resolve_request(p.PRONE, crouch)).is_equal(p.CROUCHING)
	assert_int(PostureComponent.resolve_request(p.PRONE, jump)).is_equal(p.CROUCHING)
	assert_int(PostureComponent.resolve_request(p.CROUCHING, jump)).is_equal(p.STANDING)
	assert_int(PostureComponent.resolve_request(p.STANDING, jump)).is_equal(p.STANDING)
