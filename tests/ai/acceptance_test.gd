# Criterio de aceptación de la IA (GDD §11.2) con física real, más LOD de IA y navmesh.
# "Un jugador expuesto y quieto a 50 m de un bandido debe recibir impactos en 1-2 s."
# Se mide desde que el bandido le detecta hasta el primer daño, con su fusil real.
extends GdUnitTestSuite

const BANDIT_SCENE: String = "res://scenes/ai/bandit.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const TRIALS: int = 10

var _world: Node3D
var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	Ballistics.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	var floor_node := CSGBox3D.new()
	floor_node.size = Vector3(300, 1, 300)
	floor_node.use_collision = true
	_world.add_child(floor_node)
	floor_node.position.y = -0.5
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	# Sin reaparición durante la medida.
	_player.respawn_time_s = 1000.0
	_player.global_position = Vector3(0, 0, -50)


func after_test() -> void:
	Ballistics.clear()
	NetManager.close()


func _rifle_bandit(trial: int) -> HumanNPC:
	GameState.world_seed = 1000 + trial
	var npc: HumanNPC = (load(BANDIT_SCENE) as PackedScene).instantiate() as HumanNPC
	npc.name = "Bandit%d" % trial
	_world.add_child(npc)
	npc.global_position = Vector3.ZERO
	var inv: Inventory = npc.inventory.inventory
	var old: ItemInstance = inv.item_in(Inventory.Slot.PRIMARY)
	if old != null:
		inv.detach(old)
	var rifle := ItemInstance.new(load("res://data/items/assault_rifle.tres") as ItemDefinition)
	WeaponHolder.load_full(rifle)
	inv.equip(rifle, Inventory.Slot.PRIMARY)
	npc.weapons.request_switch(0)
	# Ya mirando hacia el jugador (el criterio mide la reacción, no el giro).
	npc.rotation.y = 0.0
	return npc


func test_exposed_still_player_at_50m_is_hit_within_1_to_2_seconds() -> void:
	var times: Array[float] = []
	for trial: int in TRIALS:
		Ballistics.rng.seed = trial * 7919
		_player.health.reset()
		var npc: HumanNPC = _rifle_bandit(trial)
		var spotted_at: Array[float] = [-1.0]
		var hit_at: Array[float] = [-1.0]
		var clock: Array[float] = [0.0]
		npc.perception.target_spotted.connect(func(_t: Node3D) -> void:
			if spotted_at[0] < 0.0:
				spotted_at[0] = clock[0])
		var on_damage := func(_z: BodyZones.Zone, amount: float) -> void:
			if hit_at[0] < 0.0 and amount > 0.0:
				hit_at[0] = clock[0]
		_player.health.zone_damaged.connect(on_damage)
		for tick: int in 60 * 8:
			await get_tree().physics_frame
			clock[0] += 1.0 / 60.0
			if hit_at[0] >= 0.0:
				break
		_player.health.zone_damaged.disconnect(on_damage)
		assert_float(spotted_at[0]).override_failure_message("No le detectó (intento %d)" % trial).is_greater_equal(0.0)
		times.append(hit_at[0] - spotted_at[0] if hit_at[0] >= 0.0 else INF)
		npc.free()
		Ballistics.clear()
	times.sort()
	var median: float = (times[TRIALS / 2 - 1] + times[TRIALS / 2]) * 0.5
	print("Aceptación IA: tiempos detección->impacto %s · mediana %.2f s" % [times, median])
	assert_float(median).override_failure_message("Mediana %.2f s (%s)" % [median, times]).is_between(0.8, 2.0)
	# Nunca instantáneo: siempre hay tiempo de reacción.
	assert_float(times[0]).is_greater_equal(0.3)


func test_ai_lod_levels_by_distance() -> void:
	var manager := AIManager.new()
	_world.add_child(manager)
	var npc: HumanNPC = _rifle_bandit(99)
	var players: Array[Node] = [_player]
	assert_int(manager.lod_for(Vector3(0, 0, -50), players)).is_equal(0)
	assert_int(manager.lod_for(Vector3(0, 0, 250), players)).is_equal(1)
	assert_int(manager.lod_for(Vector3(0, 0, 600), players)).is_equal(2)
	AIManager.apply_lod(npc, 2)
	assert_bool(npc.is_physics_processing()).is_false()
	assert_bool(npc.perception.is_physics_processing()).is_false()
	AIManager.apply_lod(npc, 0)
	assert_bool(npc.is_physics_processing()).is_true()


func test_navmesh_bakes_and_npc_paths_around_a_wall() -> void:
	var geometry := Node3D.new()
	_world.add_child(geometry)
	var ground := CSGBox3D.new()
	ground.size = Vector3(80, 1, 80)
	ground.use_collision = true
	ground.position.y = -0.5
	geometry.add_child(ground)
	var wall := CSGBox3D.new()
	wall.size = Vector3(20, 3, 1)
	wall.use_collision = true
	wall.position = Vector3(0, 1.5, -10)
	geometry.add_child(wall)
	var region: NavigationRegion3D = NavRegionBuilder.bake(_world, Vector3.ZERO, 40.0, null, geometry, null)
	for i: int in 120:
		await get_tree().physics_frame
		if region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 0:
			break
	assert_int(region.navigation_mesh.get_polygon_count()).is_greater(0)
	await get_tree().physics_frame
	var npc: HumanNPC = _rifle_bandit(98)
	npc.brain.stop()
	npc.move_to(Vector3(0, 0, -20), true)
	for i: int in 600:
		await get_tree().physics_frame
		if not npc.is_moving():
			break
	assert_float(Vector2(npc.global_position.x, npc.global_position.z + 20.0).length()).is_less(1.5)
