# Tests de audio: todos los sonidos que usa el juego existen y tienen archivo, los eventos
# de sonido se reproducen en su posición y se respeta el intervalo mínimo.
extends GdUnitTestSuite

## Ids que el código usa (eventos de EventBus y feedback local).
const USED_SOUNDS: Array[StringName] = [&"gunshot_rifle", &"gunshot_pistol", &"footstep",
		&"construction", &"door", &"gather_wood", &"gather_stone", &"zombie_attack", &"zombie_groan",
		&"zombie_death", &"npc_death", &"knife_swing", &"pickup", &"reload", &"weapon_switch",
		&"dry_fire", &"hurt", &"hitmarker", &"heartbeat", &"night_stinger", &"horde_horn",
		&"ui_click", &"impact_world", &"impact_flesh"]


func test_every_used_sound_exists_with_audio() -> void:
	var library: SoundLibrary = load(SoundLibrary.DEFAULT_PATH) as SoundLibrary
	for id: StringName in USED_SOUNDS:
		var sound: SoundDefinition = library.get_sound(id)
		assert_object(sound).override_failure_message("Falta el sonido '%s'" % id).is_not_null()
		assert_array(sound.streams).override_failure_message("'%s' sin audio" % id).is_not_empty()


func test_weapons_use_known_shot_sounds() -> void:
	var library: SoundLibrary = load(SoundLibrary.DEFAULT_PATH) as SoundLibrary
	for path: String in ["assault_rifle", "pistol"]:
		var weapon := load("res://data/combat/weapons/%s.tres" % path) as WeaponDefinition
		assert_object(library.get_sound(weapon.shot_sound)).is_not_null()


func test_event_mapping() -> void:
	assert_str(String(AudioManager.sound_for_event(&"gunshot"))).is_equal("gunshot_rifle")
	assert_str(String(AudioManager.sound_for_event(&"footstep"))).is_equal("footstep")


func test_sound_event_plays_positional_sound() -> void:
	AudioManager._last_played.clear()
	EventBus.sound_emitted.emit(Vector3(3, 0, 4), 20.0, &"zombie_groan", null)
	var playing: bool = false
	for player: AudioStreamPlayer3D in AudioManager._players_3d:
		if player.playing and player.global_position == Vector3(3, 0, 4):
			playing = true
	assert_bool(playing).is_true()


func test_min_interval_throttles_repeats() -> void:
	AudioManager._last_played.clear()
	assert_bool(AudioManager.play_at(&"footstep", Vector3.ZERO)).is_true()
	assert_bool(AudioManager.play_at(&"footstep", Vector3.ZERO)).is_false()


func test_unknown_sound_is_ignored() -> void:
	assert_bool(AudioManager.play_ui(&"does_not_exist")).is_false()
