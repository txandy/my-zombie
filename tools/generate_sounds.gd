extends SceneTree
## Genera los sonidos placeholder del juego por síntesis (GDD §15: placeholders hasta tener
## audio final) en assets/audio/*.wav. Mono, 22 050 Hz, 16 bits. Con seed fija: siempre
## salen los mismos archivos. Para sustituir un sonido basta con reemplazar su .wav.
## Uso: godot --headless --path . -s res://tools/generate_sounds.gd

const RATE: int = 22050
const OUT_DIR: String = "res://assets/audio"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260926
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var sounds: Dictionary[String, Callable] = {
		"gunshot_rifle": _gunshot.bind(0.35, 18.0, 60.0, 0.5),
		"gunshot_pistol": _gunshot.bind(0.5, 26.0, 95.0, 0.32),
		"footstep_1": _footstep.bind(0.12), "footstep_2": _footstep.bind(0.16), "footstep_3": _footstep.bind(0.1),
		"impact_world": _impact_world, "impact_flesh": _impact_flesh, "hitmarker": _hitmarker,
		"reload": _reload, "weapon_switch": _weapon_switch, "dry_fire": _click.bind(0.05, 2600.0),
		"knife_swing": _whoosh, "hurt": _hurt, "heartbeat": _heartbeat,
		"zombie_groan_1": _groan.bind(95.0, 1.2, 0.0), "zombie_groan_2": _groan.bind(120.0, 1.0, 0.0),
		"zombie_groan_3": _groan.bind(80.0, 1.4, 0.0), "zombie_attack": _zombie_attack,
		"zombie_death": _groan.bind(110.0, 1.1, -45.0), "npc_death": _grunt,
		"door": _door, "construction": _hammer, "gather_wood": _chop, "gather_stone": _clack,
		"pickup": _rustle, "ui_click": _click.bind(0.04, 1800.0),
		"night_stinger": _drone.bind([55.0, 82.4, 110.0], 3.0), "horde_horn": _horn,
	}
	for sound_name: String in sounds:
		var samples: PackedFloat32Array = sounds[sound_name].call()
		_save(sound_name, samples)
	print("Sonidos generados: %d en %s" % [sounds.size(), OUT_DIR])
	quit()


# --- Utilidades ---

func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


## Filtro paso bajo de un polo sobre todo el buffer (0 < k <= 1; menor = más grave).
func _lowpass(samples: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y: float = 0.0
	for i: int in samples.size():
		y += k * (samples[i] - y)
		samples[i] = y
	return samples


func _mix(into: PackedFloat32Array, other: PackedFloat32Array, gain: float, offset_s: float = 0.0) -> void:
	var start: int = int(offset_s * RATE)
	for i: int in other.size():
		if start + i < into.size():
			into[start + i] += other[i] * gain


func _decaying_noise(seconds: float, decay: float, k: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	for i: int in samples.size():
		samples[i] = _noise() * exp(-float(i) / RATE * decay)
	return _lowpass(samples, k)


func _tone(seconds: float, freq_start: float, freq_end: float, decay: float, saw: bool = false) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / RATE
		phase += lerpf(freq_start, freq_end, t / seconds) / RATE
		var wave: float = (fmod(phase, 1.0) * 2.0 - 1.0) if saw else sin(phase * TAU)
		samples[i] = wave * exp(-t * decay)
	return samples


# --- Sonidos ---

func _gunshot(brightness: float, decay: float, thump_hz: float, seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(seconds, decay, brightness)
	_mix(samples, _tone(seconds, thump_hz * 1.6, thump_hz, 25.0), 0.9)
	_mix(samples, _decaying_noise(seconds, 5.0, 0.08), 0.35)
	return samples


func _footstep(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(seconds, 45.0, _rng.randf_range(0.08, 0.18))
	_mix(samples, _tone(0.03, 180.0, 120.0, 90.0), 0.3)
	return samples


func _impact_world() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(0.14, 55.0, 0.7)
	_mix(samples, _tone(0.1, 1900.0, 1500.0, 60.0), 0.25)
	return samples


func _impact_flesh() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(0.16, 30.0, 0.06)
	_mix(samples, _tone(0.16, 140.0, 90.0, 28.0), 0.9)
	return samples


func _hitmarker() -> PackedFloat32Array:
	return _tone(0.07, 2500.0, 2300.0, 70.0)


func _click(seconds: float, freq: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _tone(seconds, freq, freq * 0.9, 110.0)
	_mix(samples, _decaying_noise(seconds, 140.0, 0.9), 0.5)
	return samples


func _reload() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(1.0)
	_mix(samples, _decaying_noise(0.3, 12.0, 0.12), 0.2, 0.0)
	_mix(samples, _click(0.06, 2900.0), 0.9, 0.08)
	_mix(samples, _click(0.06, 2400.0), 0.9, 0.5)
	_mix(samples, _click(0.08, 3200.0), 1.0, 0.8)
	return samples


func _weapon_switch() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(0.3, 10.0, 0.1)
	_mix(samples, _click(0.05, 2200.0), 0.7, 0.05)
	_mix(samples, _click(0.05, 2700.0), 0.7, 0.2)
	return samples


func _whoosh() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(0.28)
	for i: int in samples.size():
		samples[i] = _noise() * sin(PI * float(i) / samples.size())
	return _lowpass(samples, 0.25)


func _hurt() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _tone(0.3, 90.0, 55.0, 12.0)
	_mix(samples, _decaying_noise(0.3, 14.0, 0.05), 0.6)
	return samples


func _heartbeat() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(0.9)
	_mix(samples, _tone(0.2, 60.0, 45.0, 22.0), 1.0, 0.0)
	_mix(samples, _tone(0.2, 55.0, 40.0, 26.0), 0.75, 0.28)
	return samples


func _groan(base_hz: float, seconds: float, bend_hz: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / RATE
		var freq: float = base_hz + bend_hz * t / seconds + sin(t * TAU * 5.0) * 6.0
		phase += freq / RATE
		var envelope: float = minf(t / 0.2, 1.0) * minf((seconds - t) / 0.3, 1.0)
		samples[i] = (fmod(phase, 1.0) * 2.0 - 1.0) * (0.7 + 0.3 * _noise()) * envelope
	return _lowpass(samples, 0.12)


func _zombie_attack() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _groan(150.0, 0.45, -40.0)
	_mix(samples, _impact_flesh(), 0.8, 0.25)
	return samples


func _grunt() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _tone(0.5, 190.0, 110.0, 6.0, true)
	return _lowpass(samples, 0.15)


func _door() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(0.7)
	var phase: float = 0.0
	for i: int in int(0.55 * RATE):
		var t: float = float(i) / RATE
		phase += (380.0 + sin(t * TAU * 7.0) * 120.0) / RATE
		samples[i] = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.35 * sin(PI * t / 0.55)
	_mix(samples, _impact_flesh(), 0.7, 0.55)
	return _lowpass(samples, 0.35)


func _hammer() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _tone(0.3, 170.0, 120.0, 30.0)
	_mix(samples, _decaying_noise(0.1, 70.0, 0.6), 0.6)
	return samples


func _chop() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(0.25, 28.0, 0.3)
	_mix(samples, _tone(0.2, 240.0, 180.0, 30.0), 0.7)
	return samples


func _clack() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _decaying_noise(0.2, 50.0, 0.85)
	_mix(samples, _tone(0.15, 950.0, 800.0, 45.0), 0.4)
	return samples


func _rustle() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(0.15)
	for i: int in samples.size():
		samples[i] = _noise() * sin(PI * float(i) / samples.size()) * 0.6
	return _lowpass(samples, 0.4)


func _drone(freqs: Array, seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	for i: int in samples.size():
		var t: float = float(i) / RATE
		var value: float = 0.0
		for freq: float in freqs:
			value += sin(t * TAU * freq)
		samples[i] = value / freqs.size() * sin(PI * t / seconds)
	return samples


func _horn() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(2.6)
	for i: int in samples.size():
		var t: float = float(i) / RATE
		var vibrato: float = sin(t * TAU * 4.0) * 2.0
		var wave: float = fmod(t * (110.0 + vibrato), 1.0) * 2.0 - 1.0 + (fmod(t * (165.0 + vibrato), 1.0) * 2.0 - 1.0) * 0.6
		samples[i] = wave * minf(t / 0.6, 1.0) * minf((2.6 - t) / 0.5, 1.0) * 0.5
	return _lowpass(samples, 0.2)


func _save(sound_name: String, samples: PackedFloat32Array) -> void:
	var peak: float = 0.0001
	for s: float in samples:
		peak = maxf(peak, absf(s))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err: Error = wav.save_to_wav(ProjectSettings.globalize_path(OUT_DIR.path_join(sound_name + ".wav")))
	if err != OK:
		push_error("No se pudo guardar %s: %s" % [sound_name, error_string(err)])
