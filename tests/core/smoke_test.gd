# Test de humo: comprueba que la suite arranca en headless y que el proyecto
# mantiene la configuración base de M0.
extends GdUnitTestSuite


func test_renderer_is_forward_plus() -> void:
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_str(method).is_equal("forward_plus")


func test_untyped_declaration_is_error() -> void:
	var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration")
	assert_int(level).is_equal(2)


func test_movement_actions_exist() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right",
			&"jump", &"sprint", &"crouch", &"prone", &"lean_left", &"lean_right"]:
		assert_bool(InputMap.has_action(action)).override_failure_message(
			"Falta la acción '%s' en el input map" % action).is_true()
