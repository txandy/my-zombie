extends Node
## Audio del juego (autoload `AudioManager`). GDD §15: "el audio es gameplay": disparos y
## pasos posicionales y reconocibles.
##
## - Sonidos del mundo: escucha EventBus.sound_emitted (los mismos eventos que oye la IA) y
##   los reproduce en su posición. En coop el host los reenvía a los clientes.
## - Impactos: Ballistics.projectile_impacted (carne o superficie).
## - Día/noche y hordas: avisos globales.
## - Feedback local (recarga, cambio de arma, daño, hitmarker, latido): play_ui().
## Usa un pool de reproductores para no crear nodos por sonido.

const POOL_3D: int = 32
const POOL_UI: int = 8

var library: SoundLibrary

var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_ui: int = 0
var _last_played: Dictionary[StringName, float] = {}
var _heartbeat_active: bool = false
var _heartbeat_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	library = load(SoundLibrary.DEFAULT_PATH) as SoundLibrary
	_rng.randomize()
	for i: int in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_players_3d.append(player)
	for i: int in POOL_UI:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players_ui.append(player)
	EventBus.sound_emitted.connect(_on_sound_emitted)
	EventBus.night_changed.connect(func(night: bool) -> void:
		if night:
			play_ui(&"night_stinger"))
	EventBus.horde_started.connect(func() -> void: play_ui(&"horde_horn"))
	Ballistics.projectile_impacted.connect(_on_impact)


func _process(delta: float) -> void:
	if not _heartbeat_active:
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = 0.9
		play_ui(&"heartbeat")


## Id de sonido para un evento de EventBus.sound_emitted.
static func sound_for_event(kind: StringName) -> StringName:
	if kind == &"gunshot":
		return &"gunshot_rifle"
	if kind == &"gather":
		return &"gather_wood"
	return kind


## Reproduce un sonido en una posición del mundo (o de interfaz si no es posicional).
func play_at(id: StringName, position: Vector3) -> bool:
	var sound: SoundDefinition = _ready_to_play(id)
	if sound == null:
		return false
	if not sound.positional:
		return _play_ui_sound(sound)
	var player: AudioStreamPlayer3D = _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players_3d.size()
	player.stream = _pick_stream(sound)
	player.volume_db = sound.volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_variation, sound.pitch_variation)
	player.max_distance = sound.max_distance_m
	player.unit_size = sound.unit_size
	player.global_position = position
	player.play()
	return true


## Sonido de interfaz / feedback local (se oye igual en todas partes).
func play_ui(id: StringName) -> bool:
	var sound: SoundDefinition = _ready_to_play(id)
	return sound != null and _play_ui_sound(sound)


## Latido en bucle mientras la salud es crítica.
func set_heartbeat(active: bool) -> void:
	_heartbeat_active = active


func _ready_to_play(id: StringName) -> SoundDefinition:
	var sound: SoundDefinition = library.get_sound(id) if library != null else null
	if sound == null or sound.streams.is_empty():
		return null
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -1000.0)) < sound.min_interval_s:
		return null
	_last_played[id] = now
	return sound


func _play_ui_sound(sound: SoundDefinition) -> bool:
	var player: AudioStreamPlayer = _players_ui[_next_ui]
	_next_ui = (_next_ui + 1) % _players_ui.size()
	player.stream = _pick_stream(sound)
	player.volume_db = sound.volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_variation, sound.pitch_variation)
	player.play()
	return true


func _pick_stream(sound: SoundDefinition) -> AudioStream:
	return sound.streams[_rng.randi_range(0, sound.streams.size() - 1)]


func _on_sound_emitted(position: Vector3, _radius_m: float, kind: StringName, _source: Node) -> void:
	play_at(sound_for_event(kind), position)


func _on_impact(position: Vector3, _normal: Vector3, hitbox: Hitbox, _source: Node) -> void:
	play_at(&"impact_flesh" if hitbox != null else &"impact_world", position)
