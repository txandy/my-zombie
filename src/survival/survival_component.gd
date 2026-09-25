class_name SurvivalComponent
extends Node
## Supervivencia del jugador (GDD §5.1): hambre, sed, temperatura corporal según el
## bioma y la hora, y stamina (esprintar, saltar y apuntar la consumen).
## El estado lo lleva el host (AGENTS.md §1.1).

signal changed()

@export var profile: SurvivalProfile
@export var health: HealthComponent
## Multiplicador del gasto de stamina (peso del inventario). Lo actualiza el jugador.
var stamina_cost_multiplier: float = 1.0
## Devuelve la temperatura ambiente normalizada (0-1) en un punto; la fija el mundo.
## Sin ella se usa un clima templado (0.5).
var climate_sampler: Callable

var hunger: float
var thirst: float
var body_temp_c: float = 37.0
var stamina: float

var _since_stamina_use_s: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	hunger = profile.max_hunger
	thirst = profile.max_thirst
	body_temp_c = 37.0
	stamina = profile.max_stamina
	changed.emit()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and not health.is_dead:
		tick(delta, delta * GameState.game_hours_per_second)


## Avanza la supervivencia: `delta_s` segundos reales, `hours` horas de juego.
func tick(delta_s: float, hours: float) -> void:
	var stomach_mult: float = profile.destroyed_stomach_multiplier if health.is_destroyed(BodyZones.Zone.STOMACH) else 1.0
	var heat_mult: float = profile.hyperthermia_thirst_multiplier if body_temp_c >= profile.hyperthermia_c else 1.0
	var hunger_rate: float = profile.hunger_per_hour * stomach_mult
	var thirst_rate: float = profile.thirst_per_hour * stomach_mult * heat_mult
	# Solo cuentan para la inanición las horas pasadas ya a 0 (importa en pasos largos).
	var starving_hours: float = maxf(_hours_at_zero(hunger, hunger_rate, hours), _hours_at_zero(thirst, thirst_rate, hours))
	hunger = maxf(hunger - hunger_rate * hours, 0.0)
	thirst = maxf(thirst - thirst_rate * hours, 0.0)
	_update_temperature(hours)
	var damage: float = profile.starvation_damage_per_hour * starving_hours
	if body_temp_c <= profile.hypothermia_c:
		damage += profile.hypothermia_damage_per_hour * hours
	if damage > 0.0:
		health.apply_damage(BodyZones.Zone.THORAX, damage, null)
	_regen_stamina(delta_s)
	changed.emit()


## Temperatura ambiente (°C) donde está el dueño ahora.
func ambient_temp_c() -> float:
	var owner_node := get_parent() as Node3D
	var climate: float = 0.5
	if climate_sampler.is_valid() and owner_node != null:
		climate = float(climate_sampler.call(owner_node.global_position))
	var temp: float = lerpf(profile.climate_min_c, profile.climate_max_c, climate)
	return temp - profile.night_drop_c * (1.0 - GameState.ambient_light)


func _update_temperature(hours: float) -> void:
	var ambient: float = ambient_temp_c()
	if ambient < profile.comfort_min_c:
		body_temp_c -= (profile.comfort_min_c - ambient) * profile.body_drift_per_hour_per_c * hours
	elif ambient > profile.comfort_max_c:
		body_temp_c += (ambient - profile.comfort_max_c) * profile.body_drift_per_hour_per_c * hours
	else:
		body_temp_c = move_toward(body_temp_c, 37.0, profile.body_recovery_per_hour * hours)
	body_temp_c = clampf(body_temp_c, 30.0, 42.0)


# --- Stamina ---

func can_sprint() -> bool:
	return stamina > 0.0


func can_jump() -> bool:
	return stamina >= profile.jump_cost * stamina_cost_multiplier


func drain_sprint(delta_s: float) -> void:
	_spend(profile.sprint_drain_per_s * delta_s)


func drain_aim(delta_s: float) -> void:
	_spend(profile.aim_drain_per_s * delta_s)


func on_jump() -> void:
	_spend(profile.jump_cost)


func _spend(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	stamina = maxf(stamina - amount * stamina_cost_multiplier, 0.0)
	_since_stamina_use_s = 0.0


func _regen_stamina(delta_s: float) -> void:
	_since_stamina_use_s += delta_s
	if _since_stamina_use_s < profile.regen_delay_s:
		return
	var rate: float = profile.regen_per_s
	if body_temp_c <= profile.hypothermia_c:
		rate *= profile.hypothermia_regen_multiplier
	stamina = minf(stamina + rate * delta_s, profile.max_stamina)


# --- Comer y beber (los usa FoodEffect en el host) ---

func eat(hunger_amount: float, thirst_amount: float) -> void:
	hunger = minf(hunger + hunger_amount, profile.max_hunger)
	thirst = minf(thirst + thirst_amount, profile.max_thirst)
	changed.emit()


func is_hungry() -> bool:
	return hunger < profile.max_hunger - 1.0


func is_thirsty() -> bool:
	return thirst < profile.max_thirst - 1.0


static func _hours_at_zero(value: float, rate: float, hours: float) -> float:
	if rate <= 0.0:
		return hours if value <= 0.0 else 0.0
	return maxf(hours - value / rate, 0.0)
