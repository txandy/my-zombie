class_name AimModel
extends RefCounted
## Modelo de puntería de un NPC humano (GDD §11.2): "difícil pero justo".
##
## - Tras detectar, espera un tiempo de reacción antes del primer disparo.
## - El error (cono angular) parte de base_spread y converge a min_spread durante
##   aim_settle_time mientras mantiene al objetivo a la vista.
## - El error crece con la distancia, el movimiento del objetivo y del NPC, la supresión
##   y las heridas en los brazos.
## - Apunta al torso; la probabilidad de cabeza sube con el asentamiento hasta un máximo.
## - Al perder de vista al objetivo, la puntería se desasienta en parte.
## Lógica pura: el RNG se inyecta (en el juego, el de combate del host).


class Context:
	extends RefCounted
	var distance_m: float = 0.0
	## Velocidad del objetivo perpendicular a la línea de tiro (m/s).
	var target_lateral_speed: float = 0.0
	var self_moving: bool = false
	## 0 = tranquilo, 1 = supresión máxima.
	var suppression: float = 0.0
	## Multiplicador por heridas (HealthComponent.spread_multiplier()).
	var injury_multiplier: float = 1.0


var profile: NPCCombatProfile
## Asentamiento de la puntería: 0 = recién adquirido, 1 = totalmente asentado.
var settle: float = 0.0

var _reaction_left_s: float = 0.0
var _had_sight: bool = false


func _init(combat_profile: NPCCombatProfile) -> void:
	profile = combat_profile


## Nuevo objetivo detectado: empieza el tiempo de reacción. Mantiene el asentamiento
## si ya estaba apuntando (reacquire tras perderlo un momento).
func on_target_acquired(rng: RandomNumberGenerator) -> void:
	_reaction_left_s = rng.randf_range(profile.reaction_time_min_s, profile.reaction_time_max_s)
	_had_sight = true


## Avanza el modelo. `visible`: si ve al objetivo en este tick.
func update(delta: float, visible: bool) -> void:
	if visible:
		_reaction_left_s = maxf(_reaction_left_s - delta, 0.0)
		if profile.aim_settle_time_s > 0.0:
			settle = minf(settle + delta / profile.aim_settle_time_s, 1.0)
		else:
			settle = 1.0
	elif _had_sight:
		settle *= 1.0 - profile.unsettle_on_lost_sight
	_had_sight = visible


func can_fire() -> bool:
	return _reaction_left_s <= 0.0


func reaction_left() -> float:
	return _reaction_left_s


## Semiángulo del error de apuntado en grados para el contexto dado.
func spread_deg(context: Context) -> float:
	# Convergencia suave (ease-out): mejora rápido al principio y se estabiliza al final.
	var t: float = 1.0 - (1.0 - settle) * (1.0 - settle)
	var spread: float = lerpf(profile.base_spread_deg, profile.min_spread_deg, t)
	spread *= 1.0 + profile.spread_per_100m * context.distance_m / 100.0
	spread += profile.spread_per_target_mps * context.target_lateral_speed
	spread += profile.suppression_spread_deg * clampf(context.suppression, 0.0, 1.0)
	if context.self_moving:
		spread *= profile.self_moving_spread_multiplier
	return spread * context.injury_multiplier


## Probabilidad actual de apuntar a la cabeza (limitada por el arquetipo).
func headshot_chance() -> float:
	return profile.max_headshot_chance * settle * settle


## Zona a la que apunta: tórax por defecto, cabeza con headshot_chance().
func pick_zone(rng: RandomNumberGenerator) -> BodyZones.Zone:
	return BodyZones.Zone.HEAD if rng.randf() < headshot_chance() else BodyZones.Zone.THORAX


## Dirección de disparo hacia `aim_point` con el error actual.
func aim_direction(from: Vector3, aim_point: Vector3, context: Context, rng: RandomNumberGenerator) -> Vector3:
	return WeaponHolder.spread_direction(aim_point - from, deg_to_rad(spread_deg(context)), rng)


## Punto al que apuntar para adelantar parcialmente a un objetivo en movimiento.
func lead_point(target_point: Vector3, target_velocity: Vector3, distance_m: float, muzzle_velocity_mps: float) -> Vector3:
	if muzzle_velocity_mps <= 0.0:
		return target_point
	var flight_s: float = distance_m / muzzle_velocity_mps
	return target_point + target_velocity * flight_s * profile.lead_fraction
