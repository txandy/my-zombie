# Tests de supervivencia: hambre, sed, inanición, estómago destruido, comida y bebida,
# temperatura corporal y stamina (incluida su integración en el movimiento del jugador).
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const Z := BodyZones.Zone

var _player: Player
var _survival: SurvivalComponent
var _profile: SurvivalProfile


func before_test() -> void:
	NetManager.start_single_player()
	GameState.ambient_light = 1.0
	var floor_node := CSGBox3D.new()
	floor_node.size = Vector3(60, 1, 60)
	floor_node.use_collision = true
	add_child(auto_free(floor_node))
	floor_node.position.y = -0.5
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_player.starting_kit = load("res://data/inventory/kits/range_kit.tres") as StartingKit
	add_child(_player)
	_player.set_physics_process(false)
	_survival = _player.survival
	_survival.set_physics_process(false)
	_profile = _survival.profile


func after_test() -> void:
	_player.free()
	GameState.ambient_light = 1.0
	NetManager.close()


func test_hunger_and_thirst_drop_with_game_hours() -> void:
	_survival.tick(0.0, 10.0)
	assert_float(_survival.hunger).is_equal_approx(100.0 - _profile.hunger_per_hour * 10.0, 0.001)
	assert_float(_survival.thirst).is_equal_approx(100.0 - _profile.thirst_per_hour * 10.0, 0.001)


func test_a_full_day_is_survivable_without_eating_but_not_two() -> void:
	# Un día (24 h) sin comer ni beber no mata; tres días sí dejan la sed a 0.
	_survival.tick(0.0, 24.0)
	assert_float(_survival.hunger).is_greater(0.0)
	assert_float(_survival.thirst).is_greater_equal(0.0)
	assert_bool(_player.health.is_dead).is_false()
	_survival.tick(0.0, 48.0)
	assert_float(_survival.thirst).is_equal(0.0)


func test_starvation_damages_thorax() -> void:
	_survival.hunger = 0.0
	var before: float = _player.health.hp(Z.THORAX)
	_survival.tick(0.0, 2.0)
	assert_float(_player.health.hp(Z.THORAX)).is_equal_approx(before - _profile.starvation_damage_per_hour * 2.0, 0.001)


func test_destroyed_stomach_accelerates_hunger_and_thirst() -> void:
	_player.health.apply_damage(Z.STOMACH, 70.0, null)
	_survival.tick(0.0, 1.0)
	assert_float(_survival.hunger).is_equal_approx(100.0 - _profile.hunger_per_hour * _profile.destroyed_stomach_multiplier, 0.001)


func test_food_and_water_restore_and_are_not_wasted_when_full() -> void:
	var food := ItemInstance.new(load("res://data/items/canned_food.tres") as ItemDefinition)
	var water := ItemInstance.new(load("res://data/items/water_bottle.tres") as ItemDefinition)
	_player.inventory.give(food)
	_player.inventory.give(water)
	_player.inventory.request_use(food.uuid)
	assert_object(_player.inventory.inventory.find(food.uuid)).is_not_null()
	_survival.tick(0.0, 12.0)
	var hunger: float = _survival.hunger
	var thirst: float = _survival.thirst
	_player.inventory.request_use(food.uuid)
	_player.inventory.request_use(water.uuid)
	assert_float(_survival.hunger).is_greater(hunger)
	assert_float(_survival.thirst).is_greater(thirst)
	assert_object(_player.inventory.inventory.find(food.uuid)).is_null()


func test_cold_night_lowers_body_temperature_then_recovers() -> void:
	_survival.climate_sampler = func(_p: Vector3) -> float: return 0.15
	GameState.ambient_light = 0.0
	_survival.tick(0.0, 8.0)
	var cold: float = _survival.body_temp_c
	assert_float(cold).is_less(37.0)
	_survival.climate_sampler = func(_p: Vector3) -> float: return 0.5
	GameState.ambient_light = 1.0
	_survival.tick(0.0, 4.0)
	assert_float(_survival.body_temp_c).is_greater(cold)


func test_hypothermia_hurts_and_slows_stamina_regen() -> void:
	_survival.body_temp_c = _profile.hypothermia_c - 0.5
	_survival.climate_sampler = func(_p: Vector3) -> float: return 0.0
	var before: float = _player.health.hp(Z.THORAX)
	_survival.tick(0.0, 1.0)
	assert_float(_player.health.hp(Z.THORAX)).is_less(before)


func test_sprinting_drains_stamina_and_zero_blocks_sprint_and_jump() -> void:
	_player.global_position = Vector3(0, 0.05, 0)
	var sprint := PlayerInputFrame.new()
	sprint.move = Vector2(0, 1)
	sprint.sprint = true
	for i: int in 30:
		await get_tree().physics_frame
		_player.step(sprint, 1.0 / 60.0)
	assert_float(_survival.stamina).is_less(_profile.max_stamina)
	_survival.stamina = 0.0
	_player.step(sprint, 1.0 / 60.0)
	assert_bool(_player.is_sprinting()).is_false()
	assert_bool(_survival.can_jump()).is_false()


func test_stamina_regenerates_after_delay() -> void:
	_survival.stamina = 20.0
	_survival.drain_sprint(0.0)
	_survival.tick(_profile.regen_delay_s * 0.5, 0.0)
	assert_float(_survival.stamina).is_equal(20.0)
	_survival.tick(1.0, 0.0)
	assert_float(_survival.stamina).is_greater(20.0)
