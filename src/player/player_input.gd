class_name PlayerInput
extends Node
## Lee el input local y lo convierte en un PlayerInputFrame por tick de física.
## También gestiona la captura del ratón (Esc la libera, clic la recupera).

## Sensibilidad del ratón en radianes por píxel. Es un ajuste del usuario, no de balance.
@export var mouse_sensitivity: float = 0.002

var _look_accum: Vector2 = Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_look_accum += motion.relative * mouse_sensitivity
		return
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Devuelve la entrada acumulada desde el último poll. Llamar una vez por tick de física.
func poll() -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	frame.look_delta = _look_accum
	frame.jump = Input.is_action_just_pressed(&"jump")
	frame.sprint = Input.is_action_pressed(&"sprint")
	frame.crouch_toggled = Input.is_action_just_pressed(&"crouch")
	frame.prone_toggled = Input.is_action_just_pressed(&"prone")
	frame.lean = int(Input.is_action_pressed(&"lean_right")) - int(Input.is_action_pressed(&"lean_left"))
	frame.fire_held = Input.is_action_pressed(&"fire")
	frame.fire_pressed = Input.is_action_just_pressed(&"fire")
	frame.aim = Input.is_action_pressed(&"aim")
	frame.reload = Input.is_action_just_pressed(&"reload")
	for slot: int in 3:
		if Input.is_action_just_pressed(StringName("weapon_%d" % (slot + 1))):
			frame.weapon_slot = slot
	_look_accum = Vector2.ZERO
	return frame
