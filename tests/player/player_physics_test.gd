# Tests de integración del Player con física real: suelo, desplazamiento y techo bajo.
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const DELTA: float = 1.0 / 60.0

var _world: Node3D
var _player: Player


func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	_add_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	# Después de add_child: al entrar en el árbol Godot reactiva _physics_process.
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0.5, 0)


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = center


func _run(frame: PlayerInputFrame, ticks: int) -> void:
	for i: int in ticks:
		await get_tree().physics_frame
		_player.step(frame, DELTA)


func _toggle(crouch: bool, prone: bool) -> PlayerInputFrame:
	var f := PlayerInputFrame.new()
	f.crouch_toggled = crouch
	f.prone_toggled = prone
	return f


func test_falls_and_lands_on_floor() -> void:
	await _run(PlayerInputFrame.new(), 60)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.05)


func test_walks_forward() -> void:
	await _run(PlayerInputFrame.new(), 30)
	var start: Vector3 = _player.global_position
	var forward := PlayerInputFrame.new()
	forward.move = Vector2(0, 1)
	await _run(forward, 60)
	var moved: float = start.z - _player.global_position.z
	var walk: float = _player.movement_profile.walk_speed
	# Un segundo andando: algo menos que walk_speed por la aceleración inicial.
	assert_float(moved).is_between(walk * 0.8, walk * 1.01)


func test_cannot_stand_under_low_ceiling() -> void:
	await _run(PlayerInputFrame.new(), 30)
	await _run(_toggle(true, false), 1)
	await _run(PlayerInputFrame.new(), 60)
	assert_int(_player.get_posture()).is_equal(PostureComponent.Posture.CROUCHING)
	# Techo a 1.4 m: cabe agachado (1.2 m) pero no de pie (1.8 m).
	_add_box(Vector3(0, 1.9, 0), Vector3(4, 1, 4))
	await _run(PlayerInputFrame.new(), 2)
	await _run(_toggle(true, false), 1)
	assert_int(_player.get_posture()).is_equal(PostureComponent.Posture.CROUCHING)


func test_can_stand_in_open_space() -> void:
	await _run(PlayerInputFrame.new(), 30)
	await _run(_toggle(false, true), 1)
	assert_int(_player.get_posture()).is_equal(PostureComponent.Posture.PRONE)
	await _run(_toggle(false, true), 1)
	assert_int(_player.get_posture()).is_equal(PostureComponent.Posture.STANDING)
