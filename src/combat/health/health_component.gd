class_name HealthComponent
extends Node
## Salud por zonas con estados (GDD §5.1). Mismo componente para el jugador y los NPCs.
##
## Solo el host modifica la salud (AGENTS.md §1.1). La aleatoriedad (sangrados, fracturas)
## usa el RNG que pasa quien aplica el daño, nunca el global, para poder testearla.

signal zone_damaged(zone: BodyZones.Zone, amount: float)
signal status_changed()
signal died(zone: BodyZones.Zone)

enum Bleed { NONE, LIGHT, HEAVY }

@export var profile: HealthProfile

var is_dead: bool = false

var _hp := PackedFloat32Array()
var _bleeding: Array[Bleed] = []
var _fractured: Array[bool] = []
var _pain_left_s: float = 0.0


func _ready() -> void:
	reset()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)


## Restaura toda la salud y quita los estados.
func reset() -> void:
	_hp.resize(BodyZones.COUNT)
	_bleeding.clear()
	_fractured.clear()
	for zone: BodyZones.Zone in BodyZones.ALL:
		_hp[zone] = profile.max_hp(zone)
		_bleeding.append(Bleed.NONE)
		_fractured.append(false)
	_pain_left_s = 0.0
	is_dead = false
	status_changed.emit()


func hp(zone: BodyZones.Zone) -> float:
	return _hp[zone]


func bleeding(zone: BodyZones.Zone) -> Bleed:
	return _bleeding[zone]


func is_fractured(zone: BodyZones.Zone) -> bool:
	return _fractured[zone]


func is_destroyed(zone: BodyZones.Zone) -> bool:
	return _hp[zone] <= 0.0


func has_pain() -> bool:
	return _pain_left_s > 0.0


## Aplica daño a una zona y tira los estados que pueda causar. Solo en el host.
func apply_damage(zone: BodyZones.Zone, amount: float, rng: RandomNumberGenerator) -> void:
	if is_dead or amount <= 0.0 or not multiplayer.is_server():
		return
	_roll_statuses(zone, amount, rng)
	_damage_zone(zone, amount)


## Avanza sangrados y dolor. Lo llama _physics_process en el host; público para los tests.
func tick(delta: float) -> void:
	if is_dead:
		return
	_pain_left_s = maxf(_pain_left_s - delta, 0.0)
	for zone: BodyZones.Zone in BodyZones.ALL:
		match _bleeding[zone]:
			Bleed.LIGHT:
				_damage_zone(zone, profile.light_bleed_dps * delta)
			Bleed.HEAVY:
				_damage_zone(zone, profile.heavy_bleed_dps * delta)
		if is_dead:
			return


# Resta vida a la zona. Si una zona no vital queda a 0, reparte el sobrante entre las demás.
func _damage_zone(zone: BodyZones.Zone, amount: float) -> void:
	var was_destroyed: bool = is_destroyed(zone)
	var overflow: float = maxf(amount - _hp[zone], 0.0)
	_hp[zone] = maxf(_hp[zone] - amount, 0.0)
	zone_damaged.emit(zone, amount - overflow)
	if is_destroyed(zone):
		if BodyZones.is_vital(zone):
			_die(zone)
			return
		if not was_destroyed:
			_pain_left_s = profile.pain_duration_s
			status_changed.emit()
		if overflow > 0.0:
			_redistribute(zone, overflow * profile.redistribution_factor)


func _redistribute(source: BodyZones.Zone, amount: float) -> void:
	var targets: Array[BodyZones.Zone] = []
	for zone: BodyZones.Zone in BodyZones.ALL:
		if zone != source and not is_destroyed(zone):
			targets.append(zone)
	if targets.is_empty():
		return
	var share: float = amount / targets.size()
	for zone: BodyZones.Zone in targets:
		# Sin nuevo reparto en cascada: el sobrante de un reparto se pierde.
		var applied: float = minf(share, _hp[zone])
		_hp[zone] -= applied
		zone_damaged.emit(zone, applied)
		if not is_destroyed(zone):
			continue
		if BodyZones.is_vital(zone):
			_die(zone)
			return
		_pain_left_s = profile.pain_duration_s
		status_changed.emit()


func _roll_statuses(zone: BodyZones.Zone, amount: float, rng: RandomNumberGenerator) -> void:
	var changed: bool = false
	# Tiradas siempre en el mismo orden para que el resultado sea reproducible con la misma seed.
	var heavy_roll: float = rng.randf()
	var light_roll: float = rng.randf()
	var fracture_roll: float = rng.randf()
	if heavy_roll < minf(amount * profile.heavy_bleed_chance_per_damage, 1.0):
		changed = _bleeding[zone] != Bleed.HEAVY
		_bleeding[zone] = Bleed.HEAVY
	elif light_roll < minf(amount * profile.light_bleed_chance_per_damage, 1.0) and _bleeding[zone] == Bleed.NONE:
		_bleeding[zone] = Bleed.LIGHT
		changed = true
	if BodyZones.is_limb(zone) and not _fractured[zone] \
			and fracture_roll < minf(amount * profile.fracture_chance_per_damage, 1.0):
		_fractured[zone] = true
		_pain_left_s = profile.pain_duration_s
		changed = true
	if changed:
		status_changed.emit()


func _die(zone: BodyZones.Zone) -> void:
	is_dead = true
	died.emit(zone)


# --- Penalizaciones (las consultan movimiento y armas) ---

func _limb_injured(check: Callable) -> bool:
	for zone: BodyZones.Zone in BodyZones.ALL:
		if check.call(zone) and (is_destroyed(zone) or _fractured[zone]):
			return true
	return false


func can_sprint() -> bool:
	return not _limb_injured(BodyZones.is_leg)


func movement_multiplier() -> float:
	return profile.leg_injury_speed_multiplier if _limb_injured(BodyZones.is_leg) else 1.0


func spread_multiplier() -> float:
	return profile.arm_injury_spread_multiplier if _limb_injured(BodyZones.is_arm) else 1.0


func reload_multiplier() -> float:
	return profile.arm_injury_reload_multiplier if _limb_injured(BodyZones.is_arm) else 1.0
