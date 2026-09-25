class_name InventoryScreen
extends Control
## Pantalla de inventario (GDD §14): equipo y salud a la izquierda, almacenamiento
## (bolsillos, rig, mochila) en el centro y el contenedor abierto a la derecha.
## Solo presentación: lee el modelo y envía solicitudes; nunca lo modifica (AGENTS.md §4).
##
## Controles: arrastrar = mover/equipar/unir · R al arrastrar = rotar ·
## Shift+arrastrar = dividir a la mitad · soltar fuera = tirar al suelo ·
## Ctrl+clic = transferencia rápida · clic derecho = usar · 4-0 sobre un objeto = atajo.


class DragState:
	extends RefCounted
	var item: ItemInstance
	var rotated: bool
	var start_rotated: bool
	var grab: Vector2i
	## >0 si se está dividiendo el stack.
	var split_amount: int = 0

	## Celda agarrada, ajustada si se ha rotado durante el arrastre.
	func grab_cell() -> Vector2i:
		return grab if rotated == start_rotated else Vector2i(grab.y, grab.x)


const QUICK_KEYS: Array[Key] = [KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const SLOT_LABELS: Dictionary[Inventory.Slot, String] = {
	Inventory.Slot.HELMET: "Casco", Inventory.Slot.TORSO: "Chaleco / rig",
	Inventory.Slot.BACKPACK: "Mochila", Inventory.Slot.PRIMARY: "Arma principal",
	Inventory.Slot.SECONDARY: "Arma secundaria", Inventory.Slot.PISTOL: "Pistola",
	Inventory.Slot.MELEE: "Cuerpo a cuerpo",
}

@export var component: InventoryComponent
@export var health: HealthComponent
@export var player_input: PlayerInput

var drag: DragState
var is_open: bool = false

var _hovered: ItemInstance
var _drag_preview: ColorRect
var _external_title: String = ""
var _body: HBoxContainer
var _details: Label
var _message: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	component.inventory_changed.connect(_rebuild_if_open)
	component.external_opened.connect(_on_external_opened)
	component.request_rejected.connect(func(reason: String) -> void: _message.text = reason)
	_build_frame()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory") or (is_open and event.is_action_pressed(&"ui_cancel")):
		set_open(not is_open)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not is_open or key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_R and drag != null:
		drag.rotated = not drag.rotated and drag.item.definition.rotatable
		_resize_preview()
		get_viewport().set_input_as_handled()
	elif QUICK_KEYS.has(key.physical_keycode) and _hovered != null:
		component.request_bind_quick(quick_key_number(key.physical_keycode), _hovered.uuid)
		get_viewport().set_input_as_handled()


static func quick_key_number(key: Key) -> int:
	return 10 if key == KEY_0 else int(key - KEY_0)


func set_open(open: bool) -> void:
	is_open = open
	visible = open
	player_input.gameplay_enabled = not open
	if not open:
		component.request_close_externals()
		_external_title = ""
	_rebuild_if_open()


func _on_external_opened(_container: ItemContainer, title: String) -> void:
	_external_title = title
	if is_open:
		_rebuild_if_open()
	else:
		set_open(true)


# --- Construcción ---

func _build_frame() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.02, 0.03, 0.82)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 32)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
	column.add_child(_message)
	_details = Label.new()
	_details.custom_minimum_size.y = 60
	column.add_child(_details)
	var hint := Label.new()
	hint.text = "Arrastrar: mover · R: rotar · Shift+arrastrar: dividir · Soltar fuera: tirar · Ctrl+clic: transferir · Clic dcho: usar · 4-0 sobre objeto: atajo · Tab/Esc: cerrar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	column.add_child(hint)


func _rebuild_if_open() -> void:
	if not is_open or drag != null:
		return
	for child: Node in _body.get_children():
		child.queue_free()
	_body.add_child(_build_equipment_column())
	_body.add_child(_build_storage_column())
	var external: Control = _build_external_column()
	if external != null:
		_body.add_child(external)
	_message.text = ""


func _build_equipment_column() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_title("Equipo"))
	for slot: Inventory.Slot in SLOT_LABELS:
		var view := SlotView.new()
		view.setup(self, slot, SLOT_LABELS[slot])
		box.add_child(view)
	var weight := Label.new()
	var inv: Inventory = component.inventory
	weight.text = "Peso: %.1f kg (penaliza desde %.0f kg)" % [inv.total_weight(), inv.profile.weight_penalty_start_kg]
	box.add_child(weight)
	box.add_child(_health_summary())
	return box


func _build_storage_column() -> Control:
	var box := VBoxContainer.new()
	var inv: Inventory = component.inventory
	box.add_child(_title("Bolsillos"))
	box.add_child(_grids_row(inv.pockets))
	for slot: Inventory.Slot in [Inventory.Slot.TORSO, Inventory.Slot.BACKPACK]:
		var item: ItemInstance = inv.item_in(slot)
		if item != null and item.contents != null:
			box.add_child(_title(item.definition.display_name))
			box.add_child(_grids_row(item.contents))
	return box


func _build_external_column() -> Control:
	var externals: Array = component.inventory.external.values()
	if externals.is_empty():
		return null
	var box := VBoxContainer.new()
	box.add_child(_title(_external_title.capitalize() if _external_title != "" else "Contenedor"))
	for container: ItemContainer in externals:
		box.add_child(_grids_row(container))
	return box


func _grids_row(container: ItemContainer) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for g: int in container.grids.size():
		var view := GridView.new()
		view.setup(self, container, g)
		row.add_child(view)
	return row


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _health_summary() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	# Dos zonas por línea para que quepa bajo los slots.
	var lines: PackedStringArray = []
	for i: int in range(0, BodyZones.ALL.size(), 2):
		var pair: PackedStringArray = []
		for zone: BodyZones.Zone in BodyZones.ALL.slice(i, i + 2):
			pair.append("%s %.0f/%.0f" % [BodyZones.display_name(zone), health.hp(zone), health.profile.max_hp(zone)])
		lines.append("    ".join(pair))
	label.text = "\n".join(lines)
	return label


# --- Dibujo de objetos ---

func draw_item(canvas: Control, item: ItemInstance, rect: Rect2) -> void:
	var inner: Rect2 = rect.grow(-2)
	canvas.draw_rect(inner, item.definition.icon_color.darkened(0.35))
	canvas.draw_rect(inner, item.definition.icon_color.lightened(0.2), false, 1.0)
	var font: Font = canvas.get_theme_default_font()
	canvas.draw_string(font, inner.position + Vector2(3, 12), item.definition.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 6, 10, Color(0.95, 0.95, 0.95))
	var corner: String = _corner_text(item)
	if corner != "":
		canvas.draw_string(font, inner.end - Vector2(inner.size.x - 3, 4), corner,
				HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 6, 11, Color(1, 0.95, 0.7))
	for key: int in component.quick_bindings:
		if component.quick_bindings[key] == item.uuid:
			canvas.draw_string(font, Vector2(inner.end.x - 12, inner.position.y + 12), str(key % 10),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.85, 1))


func _corner_text(item: ItemInstance) -> String:
	if item.quantity > 1:
		return str(item.quantity)
	if item.definition.weapon != null and item.definition.weapon.kind == WeaponDefinition.Kind.FIREARM:
		return "%d/%d" % [int(item.state.get("rounds", 0)), item.definition.weapon.magazine_size]
	if item.durability >= 0.0 and item.definition.armor != null:
		return "%.0f/%.0f" % [item.durability, item.definition.armor.max_durability]
	return ""


# --- Interacción ---

func set_hovered(item: ItemInstance) -> void:
	if item == _hovered:
		return
	_hovered = item
	_details.text = _describe(item) if item != null else ""


func _describe(item: ItemInstance) -> String:
	var def: ItemDefinition = item.definition
	var lines: PackedStringArray = ["%s  ·  %d×%d  ·  %.2f kg" % [def.display_name, def.size.x, def.size.y, item.weight_kg()]]
	if def.description != "":
		lines.append(def.description)
	if def.ammo != null:
		lines.append("Daño %.0f · Penetración %.0f · %.0f m/s" % [def.ammo.damage, def.ammo.penetration, def.ammo.muzzle_velocity_mps])
	if def.armor != null:
		lines.append("Clase %d · Durabilidad %.0f/%.0f" % [def.armor.armor_class, item.durability, def.armor.max_durability])
	if def.weapon != null and def.weapon.kind == WeaponDefinition.Kind.FIREARM:
		var loaded := item.state.get("ammo", def.weapon.default_ammo) as AmmoDefinition
		lines.append("%s · cargador %d/%d (%s)" % [def.weapon.caliber, int(item.state.get("rounds", 0)), def.weapon.magazine_size, loaded.display_name])
	if def.use_effect != null:
		lines.append("Clic derecho para usar")
	return "\n".join(lines)


func on_item_clicked(item: ItemInstance, button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_RIGHT:
		component.request_use(item.uuid)
	elif button.button_index == MOUSE_BUTTON_LEFT and button.ctrl_pressed:
		component.request_quick_move(item.uuid)


func begin_drag(item: ItemInstance, rotated: bool, grab: Vector2i) -> DragState:
	drag = DragState.new()
	drag.item = item
	drag.rotated = rotated
	drag.start_rotated = rotated
	drag.grab = grab
	if Input.is_key_pressed(KEY_SHIFT) and item.quantity > 1:
		drag.split_amount = item.quantity / 2
	_drag_preview = ColorRect.new()
	_drag_preview.color = item.definition.icon_color
	_drag_preview.modulate.a = 0.7
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_preview()
	set_drag_preview(_drag_preview)
	return drag


func _resize_preview() -> void:
	if _drag_preview != null and drag != null:
		_drag_preview.size = Vector2(drag.item.definition.footprint(drag.rotated)) * GridView.CELL_PX


func end_drag() -> void:
	drag = null
	_drag_preview = null
	_rebuild_if_open.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and drag != null:
		end_drag()


# Soltar sobre el fondo (fuera de cualquier rejilla o slot) = tirar al suelo.
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is DragState


func _drop_data(_at: Vector2, data: Variant) -> void:
	component.request_drop((data as DragState).item.uuid)
	end_drag()
