class_name SoundLibrary
extends Resource
## Todos los sonidos del juego, por id (data/audio/sound_library.tres).

const DEFAULT_PATH: String = "res://data/audio/sound_library.tres"

@export var sounds: Array[SoundDefinition] = []

var _by_id: Dictionary[StringName, SoundDefinition] = {}


func get_sound(id: StringName) -> SoundDefinition:
	if _by_id.is_empty():
		for sound: SoundDefinition in sounds:
			_by_id[sound.id] = sound
	return _by_id.get(id) as SoundDefinition
