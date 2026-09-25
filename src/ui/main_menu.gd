extends Control
## Menú principal: partida nueva (seed opcional), continuar, cargar/borrar partidas
## guardadas y escenas de pruebas. Solo presentación: delega en SaveSystem y cambia de escena.

const WORLD_SCENE: String = "res://scenes/world/world.tscn"
const TEST_SCENES: Dictionary[String, String] = {
	"Galería de tiro": "res://scenes/test/shooting_range.tscn",
	"Arena de IA": "res://scenes/test/ai_arena.tscn",
}

var _seed_edit: LineEdit
var _saves_box: VBoxContainer
var _name_edit: LineEdit
var _address_edit: LineEdit


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var title := Label.new()
	title.text = "[Nombre provisional]"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_new_game_row())
	column.add_child(_coop_rows())
	var latest: Array[Dictionary] = SaveSystem.list_saves()
	if not latest.is_empty():
		column.add_child(_button("Continuar (%s)" % latest[0].name, _load.bind(String(latest[0].name))))
	column.add_child(_label("Partidas guardadas"))
	_saves_box = VBoxContainer.new()
	column.add_child(_saves_box)
	_refresh_saves()
	column.add_child(_label("Pruebas"))
	for scene_name: String in TEST_SCENES:
		column.add_child(_button(scene_name, get_tree().change_scene_to_file.bind(TEST_SCENES[scene_name])))
	column.add_child(_button("Salir", get_tree().quit))


func _new_game_row() -> Control:
	var row := HBoxContainer.new()
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "Seed (vacío = aleatoria)"
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_seed_edit)
	row.add_child(_button("Nueva partida", _new_game))
	return row


func _refresh_saves() -> void:
	for child: Node in _saves_box.get_children():
		child.queue_free()
	for save: Dictionary in SaveSystem.list_saves():
		var row := HBoxContainer.new()
		var info := Label.new()
		var meta: Dictionary = save.meta
		info.text = "%s · día %d · %s" % [save.name, int(meta.get("day", 1)),
				Time.get_datetime_string_from_unix_time(int(meta.get("saved_at", 0)), true)]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		row.add_child(_button("Cargar", _load.bind(String(save.name))))
		row.add_child(_button("Borrar", _delete.bind(String(save.name))))
		_saves_box.add_child(row)


## Coop (GDD §12): hospedar una partida nueva o unirse a un host por IP.
func _coop_rows() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("Cooperativo"))
	var row := HBoxContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.text = NetManager.player_name
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.custom_minimum_size.x = 140
	row.add_child(_name_edit)
	_address_edit = LineEdit.new()
	_address_edit.text = NetManager.join_address
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_address_edit)
	row.add_child(_button("Unirse", _join))
	row.add_child(_button("Hospedar", _host))
	box.add_child(row)
	return box


func _host() -> void:
	_start_new_game(NetManager.Mode.HOST)


func _join() -> void:
	NetManager.mode = NetManager.Mode.CLIENT
	NetManager.player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Jugador"
	NetManager.join_address = _address_edit.text.strip_edges()
	SaveSystem.pending_load = ""
	get_tree().change_scene_to_file(WORLD_SCENE)


func _new_game() -> void:
	_start_new_game(NetManager.Mode.SINGLE)


func _start_new_game(net_mode: NetManager.Mode) -> void:
	NetManager.mode = net_mode
	NetManager.player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Jugador"
	var text: String = _seed_edit.text.strip_edges()
	SaveSystem.pending_load = ""
	SaveSystem.pending_seed = text.to_int() if text.is_valid_int() else (hash(text) if text != "" else 0)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _load(save_name: String) -> void:
	NetManager.mode = NetManager.Mode.SINGLE
	SaveSystem.pending_load = save_name
	get_tree().change_scene_to_file(WORLD_SCENE)


func _delete(save_name: String) -> void:
	SaveSystem.delete_save(save_name)
	_refresh_saves()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	return label
