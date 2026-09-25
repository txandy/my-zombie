# Integración inventario <-> combate: armas y armadura desde el equipo, recarga con
# munición real, cambio de tipo de munición, desgaste persistente y objetos médicos.
extends GdUnitTestSuite

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const Z := BodyZones.Zone

var _player: Player


func before_test() -> void:
	NetManager.start_single_player()
	Ballistics.clear()
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_player.starting_kit = load("res://data/inventory/kits/range_kit.tres") as StartingKit
	add_child(_player)
	_player.set_physics_process(false)


func after_test() -> void:
	_player.free()
	Ballistics.clear()
	NetManager.close()


func _inv() -> Inventory:
	return _player.inventory.inventory


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _reload_and_wait() -> void:
	_player.weapons.request_reload()
	await _ticks(ceili(_player.weapons.current().reload_time_s * Engine.physics_ticks_per_second) + 2)


func test_kit_equips_weapons_and_armor() -> void:
	assert_str(String(_player.weapons.current().id)).is_equal("assault_rifle")
	assert_int(_player.weapons.current_rounds()).is_equal(30)
	assert_object(_player.armor.piece_for(Z.HEAD)).is_not_null()
	assert_object(_player.armor.piece_for(Z.THORAX)).is_not_null()
	assert_int(_inv().count_ammo(&"762x39_ps")).is_equal(120)


func test_armor_wear_is_stored_in_item() -> void:
	var vest: ItemInstance = _inv().item_in(Inventory.Slot.TORSO)
	var before: float = vest.durability
	var hp_ammo := load("res://data/combat/ammo/762x39_hp.tres") as AmmoDefinition
	var receiver: DamageReceiver = _player.get_node("DamageReceiver") as DamageReceiver
	receiver.receive_bullet(Z.THORAX, hp_ammo, null, Ballistics.rng)
	assert_float(vest.durability).is_less(before)
	# Tras volver a sincronizar el equipo (p. ej. al quitárselo y ponérselo) conserva el desgaste.
	var worn: float = vest.durability
	_inv().unequip_to_storage(Inventory.Slot.TORSO)
	_inv().equip(vest, Inventory.Slot.TORSO)
	assert_float(_player.armor.piece_for(Z.THORAX).durability).is_equal(worn)


func test_reload_consumes_inventory_ammo() -> void:
	_player.weapons.current_item().state["rounds"] = 5
	await _reload_and_wait()
	assert_int(_player.weapons.current_rounds()).is_equal(30)
	assert_int(_inv().count_ammo(&"762x39_ps")).is_equal(95)


func test_reload_switches_ammo_type_and_returns_rounds() -> void:
	_inv().take_ammo(&"762x39_ps", 1000)
	_player.weapons.current_item().state["rounds"] = 10
	await _reload_and_wait()
	assert_str(String(_player.weapons.loaded_ammo().id)).is_equal("762x39_hp")
	assert_int(_player.weapons.current_rounds()).is_equal(30)
	assert_int(_inv().count_ammo(&"762x39_ps")).is_equal(10)
	assert_int(_inv().count_ammo(&"762x39_hp")).is_equal(30)


func test_reload_without_ammo_fails() -> void:
	_inv().take_ammo(&"762x39_ps", 1000)
	_inv().take_ammo(&"762x39_hp", 1000)
	_player.weapons.current_item().state["rounds"] = 0
	var failed: Array[bool] = [false]
	_player.weapons.reload_failed.connect(func() -> void: failed[0] = true)
	_player.weapons.request_reload()
	assert_bool(failed[0]).is_true()
	assert_bool(_player.weapons.is_reloading()).is_false()


func test_unequipping_primary_removes_it_from_weapons() -> void:
	_inv().unequip_to_storage(Inventory.Slot.PRIMARY)
	assert_str(String(_player.weapons.current().id)).is_not_equal("assault_rifle")


func test_bandage_stops_light_bleeding() -> void:
	var health: HealthComponent = _player.health
	var profile := health.profile.duplicate() as HealthProfile
	profile.light_bleed_chance_per_damage = 1.0
	profile.heavy_bleed_chance_per_damage = 0.0
	health.profile = profile
	health.apply_damage(Z.LEFT_LEG, 5.0, RandomNumberGenerator.new())
	assert_bool(health.has_bleeding(HealthComponent.Bleed.LIGHT)).is_true()
	var bandage: ItemInstance = _find_by_id(&"bandage")
	var before: int = bandage.quantity
	_player.inventory.request_use(bandage.uuid)
	assert_bool(health.has_bleeding(HealthComponent.Bleed.LIGHT)).is_false()
	assert_int(bandage.quantity).is_equal(before - 1)


func test_medical_item_is_not_wasted_without_injury() -> void:
	var tourniquet: ItemInstance = _find_by_id(&"tourniquet")
	var before: int = tourniquet.quantity
	_player.inventory.request_use(tourniquet.uuid)
	assert_int(tourniquet.quantity).is_equal(before)


func test_painkillers_suppress_pain() -> void:
	var health: HealthComponent = _player.health
	health.apply_damage(Z.LEFT_ARM, 70.0, RandomNumberGenerator.new())
	assert_bool(health.has_pain()).is_true()
	_player.inventory.request_use(_find_by_id(&"painkillers").uuid)
	assert_bool(health.has_pain()).is_false()


func _find_by_id(id: StringName) -> ItemInstance:
	for container: ItemContainer in _inv().storage():
		var found: ItemInstance = _search(container, id)
		if found != null:
			return found
	return null


func _search(container: ItemContainer, id: StringName) -> ItemInstance:
	for item: ItemInstance in container.items():
		if item.definition.id == id:
			return item
		if item.contents != null:
			var nested: ItemInstance = _search(item.contents, id)
			if nested != null:
				return nested
	return null
