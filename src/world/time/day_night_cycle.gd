class_name DayNightCycle
extends Node
## Ciclo día/noche (GDD §4.1, §4.5). El host avanza la hora en GameState; todos los
## peers calculan la iluminación a partir de ella (sol, color, niebla, luz ambiental).
## La luz ambiental afecta a la visión de la IA (Perception) y a los zombis.

@export var settings: DayNightSettings
@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment
## Multiplicador de velocidad del tiempo (pruebas, "dormir").
@export var time_scale: float = 1.0


func _ready() -> void:
	GameState.game_hours_per_second = 24.0 / settings.day_length_s * time_scale
	if multiplayer.is_server():
		GameState.day = 1
		GameState.hour = settings.start_hour
		GameState.is_night = is_night_at(GameState.hour)
	apply_lighting()


func _process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta * time_scale)
	apply_lighting()


## Avanza el reloj `seconds` segundos reales. Solo en el host.
func advance(seconds: float) -> void:
	if not multiplayer.is_server():
		return
	GameState.hour += seconds * 24.0 / settings.day_length_s
	while GameState.hour >= 24.0:
		GameState.hour -= 24.0
		GameState.day += 1
		EventBus.day_started.emit(GameState.day)
	var night: bool = is_night_at(GameState.hour)
	if night != GameState.is_night:
		GameState.is_night = night
		EventBus.night_changed.emit(night)


func is_night_at(hour: float) -> bool:
	return hour < settings.sunrise_hour or hour >= settings.sunset_hour


## Cuánto "día" hay a una hora: 0 de noche, 1 de día, rampa en el crepúsculo.
func daylight_at(hour: float) -> float:
	var half: float = settings.twilight_hours * 0.5
	var rise: float = clampf((hour - (settings.sunrise_hour - half)) / settings.twilight_hours, 0.0, 1.0)
	var set_: float = clampf(((settings.sunset_hour + half) - hour) / settings.twilight_hours, 0.0, 1.0)
	return minf(rise, set_)


## ¿Esta noche toca horda? (la noche que empieza el último de cada ciclo de N días)
func is_horde_night(day: int) -> bool:
	return settings.horde_every_days > 0 and day % settings.horde_every_days == 0


func apply_lighting() -> void:
	var daylight: float = daylight_at(GameState.hour)
	GameState.ambient_light = lerpf(settings.night_ambient, 1.0, daylight)
	if sun != null:
		# El sol recorre el cielo de este a oeste entre el amanecer y el anochecer.
		var span: float = settings.sunset_hour - settings.sunrise_hour
		var progress: float = (GameState.hour - settings.sunrise_hour) / span
		sun.rotation = Vector3(-sin(clampf(progress, 0.0, 1.0) * PI) * deg_to_rad(80.0) - deg_to_rad(5.0),
				deg_to_rad(90.0) - progress * PI, 0.0)
		sun.light_energy = lerpf(settings.night_sun_energy, settings.day_sun_energy, daylight)
		var dusk: float = 1.0 - absf(daylight - 0.5) * 2.0
		sun.light_color = settings.day_color.lerp(settings.dusk_color, dusk)
	if environment != null and environment.environment != null:
		var env: Environment = environment.environment
		env.fog_density = lerpf(settings.night_fog_density, settings.day_fog_density, daylight)
		env.background_energy_multiplier = lerpf(0.05, 1.0, daylight)
		env.ambient_light_energy = lerpf(0.15, 1.0, daylight)
