# Tests del ciclo día/noche: avance del reloj, cambio de día, día/noche, luz y hordas.
extends GdUnitTestSuite

var _cycle: DayNightCycle


func before_test() -> void:
	NetManager.start_single_player()
	_cycle = DayNightCycle.new()
	_cycle.settings = load("res://data/world/day_night.tres") as DayNightSettings
	add_child(_cycle)
	_cycle.set_process(false)


func after_test() -> void:
	_cycle.free()
	GameState.ambient_light = 1.0
	NetManager.close()


func test_starts_at_start_hour_on_day_one() -> void:
	assert_int(GameState.day).is_equal(1)
	assert_float(GameState.hour).is_equal(_cycle.settings.start_hour)
	assert_bool(GameState.is_night).is_false()


func test_full_day_length_advances_one_day() -> void:
	var days: Array[int] = []
	EventBus.day_started.connect(func(day: int) -> void: days.append(day))
	_cycle.advance(_cycle.settings.day_length_s)
	assert_int(GameState.day).is_equal(2)
	assert_float(GameState.hour).is_equal_approx(_cycle.settings.start_hour, 0.001)
	assert_array(days).contains_exactly([2])


func test_night_changes_emit_signal() -> void:
	var changes: Array[bool] = []
	EventBus.night_changed.connect(func(night: bool) -> void: changes.append(night))
	# De 8:00 a 21:00 (anochecer a las 20).
	_cycle.advance(_cycle.settings.day_length_s * 13.0 / 24.0)
	assert_bool(GameState.is_night).is_true()
	# Y hasta las 7:00 del día siguiente.
	_cycle.advance(_cycle.settings.day_length_s * 10.0 / 24.0)
	assert_bool(GameState.is_night).is_false()
	assert_array(changes).contains_exactly([true, false])


func test_ambient_light_is_low_at_night_and_full_at_noon() -> void:
	GameState.hour = 12.0
	_cycle.apply_lighting()
	assert_float(GameState.ambient_light).is_equal(1.0)
	GameState.hour = 2.0
	_cycle.apply_lighting()
	assert_float(GameState.ambient_light).is_equal_approx(_cycle.settings.night_ambient, 0.001)
	GameState.hour = _cycle.settings.sunset_hour
	_cycle.apply_lighting()
	assert_float(GameState.ambient_light).is_between(_cycle.settings.night_ambient + 0.01, 0.99)


func test_horde_every_n_days() -> void:
	assert_bool(_cycle.is_horde_night(7)).is_true()
	assert_bool(_cycle.is_horde_night(14)).is_true()
	assert_bool(_cycle.is_horde_night(6)).is_false()


func test_clients_do_not_advance_time() -> void:
	NetManager.join("127.0.0.1", 24693)
	var hour: float = GameState.hour
	_cycle.advance(600.0)
	assert_float(GameState.hour).is_equal(hour)
