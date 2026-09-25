# Tests de escenario del cerebro (LimboAI): patrulla, alerta, combate con cobertura,
# reacción a ser disparado, búsqueda, retirada y escuadra.
extends GdUnitTestSuite

const BANDIT_SCENE: String = "res://scenes/ai/bandit.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const Z := BodyZones.Zone

var _world: Node3D
var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	GameState.world_seed = 31
	Ballistics.clear()
	Ballistics.rng.seed = 5
	_world = auto_free(Node3D.new())
	add_child(_world)
	_add_box(Vector3(0, -0.5, 0), Vector3(300, 1, 300))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0, 200)


func after_test() -> void:
	Ballistics.clear()
	NetManager.close()


func _add_box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = center
	return body


func _bandit(at: Vector3, parent: Node = null, bandit_name: String = "Bandit") -> HumanNPC:
	var npc: HumanNPC = (load(BANDIT_SCENE) as PackedScene).instantiate() as HumanNPC
	npc.name = bandit_name
	(parent if parent != null else _world).add_child(npc)
	npc.global_position = at
	npc.home_position = at
	return npc


# Orienta el cuerpo del NPC hacia un punto (como si ya estuviera mirando hacia allí).
func _face(npc: HumanNPC, point: Vector3) -> void:
	var to_point: Vector3 = point - npc.global_position
	npc.rotation.y = atan2(-to_point.x, -to_point.z)


func _cover_point(at: Vector3) -> void:
	var point := CoverPoint.new()
	point.low = true
	_world.add_child(point)
	point.global_position = at


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_starts_patrolling_and_wanders() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	await _ticks(10)
	assert_str(String(npc.brain.state_name())).is_equal("Patrol")
	await _ticks(480)
	assert_float(npc.global_position.length()).is_greater(1.0)


func test_gunshot_puts_it_on_alert() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	await _ticks(5)
	EventBus.sound_emitted.emit(Vector3(0, 0, 150), 300.0, &"gunshot", _player)
	await _ticks(2)
	assert_str(String(npc.brain.state_name())).is_equal("Alert")


func test_spotting_player_goes_to_combat_takes_cover_and_shoots() -> void:
	# Muro bajo entre el NPC y el jugador, con un punto de cobertura detrás.
	_add_box(Vector3(4, 0.55, -3), Vector3(2.5, 1.1, 0.4))
	_cover_point(Vector3(4, 0, -2.3))
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	_player.global_position = Vector3(3, 0, -30)
	_face(npc, _player.global_position)
	# Se cuenta el daño recibido (si el jugador muere, la reaparición de desarrollo le cura).
	var damage: Array[float] = [0.0]
	_player.health.zone_damaged.connect(func(_z: BodyZones.Zone, amount: float) -> void: damage[0] += amount)
	await _ticks(420)
	assert_str(String(npc.brain.state_name())).is_equal("Combat")
	assert_float(Vector2(npc.global_position.x - 4.0, npc.global_position.z + 2.3).length()).is_less(1.2)
	assert_float(damage[0]).is_greater(0.0)


func test_being_shot_from_behind_triggers_combat() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	npc.rotation.y = 0.0
	_player.global_position = Vector3(0, 0, 40)
	await _ticks(5)
	var ammo := load("res://data/combat/ammo/9x19_pst.tres") as AmmoDefinition
	(npc.get_node("DamageReceiver") as DamageReceiver).receive_bullet(Z.LEFT_ARM, ammo, _player, Ballistics.rng)
	await _ticks(2)
	assert_str(String(npc.brain.state_name())).is_equal("Combat")
	assert_object(npc.perception.memory.target).is_same(_player)


func test_losing_the_target_leads_to_search() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	_player.global_position = Vector3(0, 0, -25)
	_face(npc, _player.global_position)
	await _ticks(120)
	assert_str(String(npc.brain.state_name())).is_equal("Combat")
	# El jugador desaparece detrás de un muro alto.
	_add_box(Vector3(0, 3, -12), Vector3(30, 6, 1))
	await _ticks(420)
	assert_bool(["Search", "Patrol"].has(String(npc.brain.state_name()))).is_true()


func test_badly_hurt_npc_retreats_and_heals() -> void:
	var npc: HumanNPC = _bandit(Vector3.ZERO)
	npc.inventory.give(ItemInstance.new(load("res://data/items/tourniquet.tres") as ItemDefinition))
	_player.global_position = Vector3(0, 0, -25)
	_face(npc, _player.global_position)
	# Se hiere ya en combate (en patrulla se curaría sin retirarse).
	for i: int in 300:
		await get_tree().physics_frame
		if npc.brain.state_name() == &"Combat":
			break
	assert_str(String(npc.brain.state_name())).is_equal("Combat")
	var profile := npc.health.profile.duplicate() as HealthProfile
	profile.heavy_bleed_chance_per_damage = 1.0
	npc.health.profile = profile
	npc.health.apply_damage(Z.RIGHT_LEG, 5.0, RandomNumberGenerator.new())
	var states: Array[String] = []
	for i: int in 300:
		await get_tree().physics_frame
		if states.is_empty() or states.back() != String(npc.brain.state_name()):
			states.append(String(npc.brain.state_name()))
	assert_array(states).contains(["Retreat"])
	assert_bool(npc.health.has_bleeding(HealthComponent.Bleed.HEAVY)).is_false()


func test_squad_shares_contacts_and_splits_roles() -> void:
	var squad := Squad.new()
	_world.add_child(squad)
	var a: HumanNPC = _bandit(Vector3(0, 0, 0), squad, "A")
	var b: HumanNPC = _bandit(Vector3(3, 0, 5), squad, "B")
	squad._ready()
	# Solo A mira hacia el jugador; B mira al lado contrario.
	_player.global_position = Vector3(0, 0, -30)
	_face(a, _player.global_position)
	b.rotation.y = PI
	await _ticks(120)
	assert_bool(a.perception.is_detected(_player)).is_true()
	assert_object(b.perception.memory.target).is_same(_player)
	var roles: Array[int] = [squad.role_of(a), squad.role_of(b)]
	assert_array(roles).contains([Squad.Role.SUPPRESS])


func _total_hp(health: HealthComponent) -> float:
	var total: float = 0.0
	for zone: BodyZones.Zone in BodyZones.ALL:
		total += health.hp(zone)
	return total
