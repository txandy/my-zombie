extends SceneTree
## Crea data/audio/sound_library.tres a partir de los .wav de assets/audio.
## Los parámetros iniciales están aquí; después se ajustan en el .tres (editor o texto).
## Uso: godot --headless --path . -s res://tools/build_sound_library.gd

## id -> [archivos (prefijo), volumen dB, variación de tono, posicional, distancia máx., unit size, intervalo]
const TABLE: Dictionary = {
	"gunshot_rifle": ["gunshot_rifle", 0.0, 0.05, true, 400.0, 40.0, 0.0],
	"gunshot_pistol": ["gunshot_pistol", -2.0, 0.05, true, 300.0, 30.0, 0.0],
	"footstep": ["footstep_", -14.0, 0.15, true, 30.0, 2.0, 0.08],
	"impact_world": ["impact_world", -8.0, 0.2, true, 50.0, 3.0, 0.0],
	"impact_flesh": ["impact_flesh", -4.0, 0.15, true, 50.0, 3.0, 0.0],
	"hitmarker": ["hitmarker", -10.0, 0.05, false, 0.0, 1.0, 0.03],
	"reload": ["reload", -6.0, 0.03, false, 0.0, 1.0, 0.0],
	"weapon_switch": ["weapon_switch", -8.0, 0.05, false, 0.0, 1.0, 0.0],
	"dry_fire": ["dry_fire", -8.0, 0.05, false, 0.0, 1.0, 0.1],
	"knife_swing": ["knife_swing", -6.0, 0.15, true, 15.0, 2.0, 0.0],
	"hurt": ["hurt", -3.0, 0.1, false, 0.0, 1.0, 0.25],
	"heartbeat": ["heartbeat", -6.0, 0.0, false, 0.0, 1.0, 0.0],
	"zombie_groan": ["zombie_groan_", -6.0, 0.15, true, 40.0, 4.0, 0.0],
	"zombie_attack": ["zombie_attack", -3.0, 0.1, true, 30.0, 4.0, 0.0],
	"zombie_death": ["zombie_death", -4.0, 0.1, true, 40.0, 4.0, 0.0],
	"npc_death": ["npc_death", -4.0, 0.1, true, 50.0, 4.0, 0.0],
	"door": ["door", -6.0, 0.08, true, 25.0, 3.0, 0.0],
	"construction": ["construction", -4.0, 0.1, true, 50.0, 5.0, 0.0],
	"gather_wood": ["gather_wood", -4.0, 0.1, true, 40.0, 4.0, 0.0],
	"gather_stone": ["gather_stone", -4.0, 0.1, true, 40.0, 4.0, 0.0],
	"pickup": ["pickup", -6.0, 0.1, true, 12.0, 1.5, 0.0],
	"ui_click": ["ui_click", -12.0, 0.05, false, 0.0, 1.0, 0.0],
	"night_stinger": ["night_stinger", -6.0, 0.0, false, 0.0, 1.0, 0.0],
	"horde_horn": ["horde_horn", -2.0, 0.0, false, 0.0, 1.0, 0.0],
}


func _init() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://assets/audio")
	var library := SoundLibrary.new()
	for id: String in TABLE:
		var row: Array = TABLE[id]
		var sound := SoundDefinition.new()
		sound.id = StringName(id)
		for file: String in files:
			if file.ends_with(".wav") and (file == row[0] + ".wav" or (String(row[0]).ends_with("_") and file.begins_with(row[0]))):
				sound.streams.append(load("res://assets/audio/" + file) as AudioStream)
		sound.volume_db = row[1]
		sound.pitch_variation = row[2]
		sound.positional = row[3]
		sound.max_distance_m = row[4]
		sound.unit_size = row[5]
		sound.min_interval_s = row[6]
		library.sounds.append(sound)
	print("Biblioteca: %d sonidos · %s" % [library.sounds.size(), error_string(ResourceSaver.save(library, SoundLibrary.DEFAULT_PATH))])
	quit()
