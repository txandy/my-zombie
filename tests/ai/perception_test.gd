# Tests de percepción: visión por zonas del cuerpo, detección acumulativa, ocultación,
# cono de visión, postura, luz, oído, supresión y memoria.
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var _world: Node3D
var _npc: CharacterBody3D
var _eye: Node3D
var _perception: Perception
var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	GameState.ambient_light = 1.0
	_world = auto_free(Node3D.new())
	add_child(_world)
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	_npc = CharacterBody3D.new()
	_eye = Node3D.new()
	_eye.position = Vector3(0, 1.6, 0)
	_npc.add_child(_eye)
	_perception = Perception.new()
	_perception.profile = load("res://data/ai/bandit_profile.tres") as NPCCombatProfile
	_perception.rules = load("res://data/ai/perception_rules.tres") as PerceptionRules
	_perception.body = _npc
	_perception.eye = _eye
	_npc.add_child(_perception)
	_world.add_child(_npc)
	_perception.set_physics_process(false)
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0, -20)


func after_test() -> void:
	NetManager.close()
	GameState.ambient_light = 1.0


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = center


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_target_in_front_is_fully_exposed() -> void:
	await _settle()
	assert_float(_perception.exposure_of(_player)).is_equal(1.0)
	assert_float(_perception.visibility_of(_player)).is_greater(0.0)


func test_detection_accumulates_over_time() -> void:
	await _settle()
	_perception.update_vision(0.2)
	assert_bool(_perception.is_detected(_player)).is_false()
	var spotted: Array[Node3D] = []
	_perception.target_spotted.connect(func(t: Node3D) -> void: spotted.append(t))
	for i: int in 30:
		_perception.update_vision(0.2)
	assert_bool(_perception.is_detected(_player)).is_true()
	assert_array(spotted).contains_exactly([_player])
	assert_vector(_perception.memory.last_known_position).is_equal(_player.global_position)


func test_wall_blocks_vision() -> void:
	_add_box(Vector3(0, 2, -10), Vector3(6, 4, 0.5))
	await _settle()
	assert_float(_perception.exposure_of(_player)).is_equal(0.0)
	for i: int in 30:
		_perception.update_vision(0.2)
	assert_bool(_perception.is_detected(_player)).is_false()


func test_low_cover_gives_partial_exposure() -> void:
	_add_box(Vector3(0, 0.55, -19), Vector3(3, 1.1, 0.4))
	await _settle()
	var exposure: float = _perception.exposure_of(_player)
	assert_float(exposure).is_greater(0.0)
	assert_float(exposure).is_less(1.0)


func test_outside_fov_is_invisible_but_very_close_is_noticed() -> void:
	_player.global_position = Vector3(0, 0, 20)
	await _settle()
	assert_float(_perception.visibility_of(_player)).is_equal(0.0)
	_player.global_position = Vector3(0, 0, 2)
	await _settle()
	assert_float(_perception.visibility_of(_player)).is_greater(0.0)


func test_distance_crouch_and_night_reduce_visibility() -> void:
	await _settle()
	var near: float = _perception.visibility_of(_player)
	_player.global_position = Vector3(0, 0, -120)
	await _settle()
	var far: float = _perception.visibility_of(_player)
	assert_float(far).is_less(near)
	GameState.ambient_light = 0.0
	assert_float(_perception.visibility_of(_player)).is_less(far)


func test_crouched_target_is_harder_to_see() -> void:
	await _settle()
	var standing: float = _perception.visibility_of(_player)
	var crouch := PlayerInputFrame.new()
	crouch.crouch_toggled = true
	_player.step(crouch, 1.0 / 60.0)
	for i: int in 30:
		_player.step(PlayerInputFrame.new(), 1.0 / 60.0)
		await get_tree().physics_frame
	assert_float(_perception.visibility_of(_player)).is_less(standing)


func test_hears_gunshot_within_radius_only() -> void:
	var heard: Array[StringName] = []
	_perception.sound_heard.connect(func(_p: Vector3, kind: StringName) -> void: heard.append(kind))
	EventBus.sound_emitted.emit(Vector3(0, 0, -500), 300.0, &"gunshot", _player)
	assert_array(heard).is_empty()
	EventBus.sound_emitted.emit(Vector3(0, 0, -200), 300.0, &"gunshot", _player)
	assert_array(heard).contains_exactly([&"gunshot"])
	assert_vector(_perception.memory.last_known_position).is_equal(Vector3(0, 0, -200))
	assert_float(_perception.memory.confidence).is_equal(0.5)


func test_ignores_sounds_from_non_hostiles() -> void:
	var heard: Array[StringName] = []
	_perception.sound_heard.connect(func(_p: Vector3, kind: StringName) -> void: heard.append(kind))
	EventBus.sound_emitted.emit(Vector3(0, 0, -5), 300.0, &"gunshot", _npc)
	assert_array(heard).is_empty()


func test_bullet_passing_close_suppresses() -> void:
	# Bala del jugador que pasa a 1 m de los ojos del NPC.
	Ballistics.projectile_fired.emit(Vector3(1, 1.6, -30), Vector3(0, 0, 700), _player)
	assert_float(_perception.suppression).is_greater(0.0)
	var before: float = _perception.suppression
	# Una bala lejana no suprime.
	Ballistics.projectile_fired.emit(Vector3(20, 1.6, -30), Vector3(0, 0, 700), _player)
	assert_float(_perception.suppression).is_equal(before)


func test_player_footsteps_are_emitted() -> void:
	var steps: Array[float] = []
	EventBus.sound_emitted.connect(func(_p: Vector3, radius: float, kind: StringName, _s: Node) -> void:
		if kind == &"footstep":
			steps.append(radius))
	_player.global_position = Vector3(0, 0.05, 0)
	var walk := PlayerInputFrame.new()
	walk.move = Vector2(0, 1)
	for i: int in 90:
		await get_tree().physics_frame
		_player.step(walk, 1.0 / 60.0)
	assert_array(steps).is_not_empty()
	assert_float(steps[0]).is_equal(_perception.rules.walk_step_radius_m)
