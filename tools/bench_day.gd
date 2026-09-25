extends Node
## Simula un día completo acelerado en el mundo generado (criterio de M5: "un ciclo de día
## completo es jugable"). El jugador se queda a cubierto en su punto de aparición, come
## y bebe cuando lo necesita, y se registra lo que pasa: noche, zombis, hambre, sed, salud.
## Uso: godot --headless --path . res://tools/bench_day.tscn -- --seed=12345

## Duración simulada de un día en segundos reales.
const DAY_SECONDS: float = 90.0

var _world: Node3D
var _player: Player
var _log: PackedStringArray = []
var _peak_zombies_day: int = 0
var _peak_zombies_night: int = 0
var _elapsed: float = 0.0
var _started: bool = false


func _ready() -> void:
	_world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node3D
	add_child(_world)
	await get_tree().create_timer(0.5).timeout
	var cycle := _world.get_node("DayNightCycle") as DayNightCycle
	cycle.time_scale = cycle.settings.day_length_s / DAY_SECONDS
	GameState.game_hours_per_second = 24.0 / DAY_SECONDS
	_player = _world.get_node("Player") as Player
	_player.set_physics_process(false)
	# Provisiones para un día (con mochila: la botella de agua no cabe en los bolsillos).
	_player.inventory.inventory.equip(ItemInstance.new(load("res://data/items/backpack_small.tres") as ItemDefinition), Inventory.Slot.BACKPACK)
	for id: String in ["canned_food", "water_bottle"]:
		_player.inventory.give(ItemInstance.new(load("res://data/items/%s.tres" % id) as ItemDefinition))
	EventBus.night_changed.connect(func(night: bool) -> void: _log.append("%s a las %05.2f (día %d)" % ["Anochece" if night else "Amanece", GameState.hour, GameState.day]))
	EventBus.day_started.connect(func(day: int) -> void: _log.append("Empieza el día %d" % day))
	_started = true


func _process(delta: float) -> void:
	if not _started:
		return
	_elapsed += delta
	var zombies: int = get_tree().get_nodes_in_group(&"zombie").size()
	if GameState.is_night:
		_peak_zombies_night = maxi(_peak_zombies_night, zombies)
	else:
		_peak_zombies_day = maxi(_peak_zombies_day, zombies)
	_eat_if_needed()
	if _elapsed >= DAY_SECONDS + 2.0:
		_report()
		get_tree().quit()


func _eat_if_needed() -> void:
	var survival: SurvivalComponent = _player.survival
	for container: ItemContainer in _player.inventory.inventory.storage():
		for item: ItemInstance in container.items():
			var food := item.definition.use_effect as FoodEffect
			var is_drink: bool = food != null and food.thirst > food.hunger
			if food != null and ((not is_drink and survival.hunger < 50.0) or (is_drink and survival.thirst < 50.0)):
				_player.inventory.request_use(item.uuid)
				_log.append("Come/bebe %s (hambre %.0f, sed %.0f)" % [item.definition.display_name, survival.hunger, survival.thirst])
				return


func _report() -> void:
	var s: SurvivalComponent = _player.survival
	print("DAY ---- Simulación de un día completo (%.0f s reales) ----" % DAY_SECONDS)
	for line: String in _log:
		print("DAY ", line)
	print("DAY Final: día %d %05.2f h · vivo=%s · hambre %.0f · sed %.0f · temp %.1f °C" % [GameState.day, GameState.hour,
			not _player.health.is_dead, s.hunger, s.thirst, s.body_temp_c])
	print("DAY Zombis activos máx.: de día %d · de noche %d" % [_peak_zombies_day, _peak_zombies_night])
