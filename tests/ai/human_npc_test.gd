# Tests del cuerpo del NPC: equipo por loadout, disparo con física real, movimiento,
# curación y cadáver saqueable.
extends GdUnitTestSuite

const BANDIT_SCENE: String = "res://scenes/ai/bandit.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const Z := BodyZones.Zone

var _world: Node3D
var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	GameState.world_seed = 777
	Ballistics.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	floor_body.position.y = -0.5
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0, -20)


func after_test() -> void:
	Ballistics.clear()
	NetManager.close()


func _bandit(at: Vector3, bandit_name: String = "Bandit") -> HumanNPC:
	var npc: HumanNPC = (load(BANDIT_SCENE) as PackedScene).instantiate() as HumanNPC
	npc.name = bandit_name
	_world.add_child(npc)
	npc.global_position = at
	return npc


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_spawns_with_weapon_and_ammo() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	assert_object(npc.weapons.current()).is_not_null()
	var weapon: WeaponDefinition = npc.weapons.current()
	assert_int(npc.weapons.current_rounds()).is_equal(weapon.magazine_size)
	assert_int(npc.inventory.count_ammo(weapon.default_ammo.id)).is_greater(0)


func test_loadout_is_reproducible_per_seed_and_name() -> void:
	var a: HumanNPC = _bandit(Vector3(0, 0, 50), "Bandit_A")
	var summary_a: String = _summary(a)
	a.free()
	var b: HumanNPC = _bandit(Vector3(0, 0, 50), "Bandit_A")
	assert_str(_summary(b)).is_equal(summary_a)


func test_detects_and_shoots_exposed_player() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	await _ticks(2)
	var total_before: float = _total_hp(_player.health)
	for i: int in 240:
		await get_tree().physics_frame
		if npc.perception.is_detected(_player):
			npc.engage(_player)
	assert_bool(npc.perception.is_detected(_player)).is_true()
	assert_float(_total_hp(_player.health)).is_less(total_before)


func test_does_not_shoot_through_walls() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 5, 0.5)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_position = Vector3(0, 2.5, -10)
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	await _ticks(2)
	var rounds: int = npc.weapons.current_rounds()
	for i: int in 120:
		await get_tree().physics_frame
		npc.engage(_player)
	assert_int(npc.weapons.current_rounds()).is_equal(rounds)


func test_moves_to_point_without_navmesh() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	npc.move_to(Vector3(6, 0, 0), true)
	await _ticks(150)
	assert_float(Vector2(npc.global_position.x - 6.0, npc.global_position.z).length()).is_less(1.0)
	assert_bool(npc.is_moving()).is_false()


func test_uses_medicine_for_heavy_bleeding() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	npc.inventory.give(ItemInstance.new(load("res://data/items/tourniquet.tres") as ItemDefinition))
	var profile := npc.health.profile.duplicate() as HealthProfile
	profile.heavy_bleed_chance_per_damage = 1.0
	npc.health.profile = profile
	npc.health.apply_damage(Z.LEFT_LEG, 5.0, RandomNumberGenerator.new())
	assert_bool(npc.should_retreat()).is_true()
	assert_bool(npc.use_best_medicine()).is_true()
	assert_bool(npc.health.has_bleeding(HealthComponent.Bleed.HEAVY)).is_false()


func test_corpse_holds_all_gear_and_can_be_looted() -> void:
	var npc: HumanNPC = _bandit(Vector3(0, 0, -21.5))
	var gear: int = npc.inventory.inventory.equipped.size()
	npc.health.apply_damage(Z.HEAD, 100.0, RandomNumberGenerator.new())
	assert_bool(npc.is_dead).is_true()
	assert_int(npc.corpse_container.items().size()).is_greater_equal(gear)
	assert_str(npc.interaction_text()).is_not_empty()
	npc.interact(_player)
	assert_object(_player.inventory.inventory.container_by_id(npc.corpse_container.id)).is_same(npc.corpse_container)


func _summary(npc: HumanNPC) -> String:
	var ids: PackedStringArray = []
	for slot: Inventory.Slot in npc.inventory.inventory.equipped:
		ids.append(String(npc.inventory.inventory.equipped[slot].definition.id))
	ids.sort()
	return ",".join(ids)


func _total_hp(health: HealthComponent) -> float:
	var total: float = 0.0
	for zone: BodyZones.Zone in BodyZones.ALL:
		total += health.hp(zone)
	return total
