class_name SlotView
extends Control
## Slot de equipo (casco, torso, mochila, armas). Acepta soltar objetos para equiparlos
## y permite arrastrar lo equipado a una rejilla. Solo presentación.

const SIZE_PX := Vector2(170, 50)

var screen: InventoryScreen
var slot: Inventory.Slot
var title: String


func setup(owner_screen: InventoryScreen, equip_slot: Inventory.Slot, label: String) -> void:
	screen = owner_screen
	slot = equip_slot
	title = label
	custom_minimum_size = SIZE_PX
	mouse_filter = Control.MOUSE_FILTER_STOP


func _item() -> ItemInstance:
	return screen.component.inventory.item_in(slot)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.1, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.37, 0.4), false, 1.0)
	var item: ItemInstance = _item()
	if item != null:
		screen.draw_item(self, item, Rect2(Vector2(4, 18), size - Vector2(8, 22)))
	draw_string(get_theme_default_font(), Vector2(6, 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.7, 0.72, 0.75))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and _item() != null:
		screen.on_item_clicked(_item(), button)
	if event is InputEventMouseMotion:
		screen.set_hovered(_item())


func _get_drag_data(_at: Vector2) -> Variant:
	var item: ItemInstance = _item()
	return screen.begin_drag(item, false, Vector2i.ZERO) if item != null else null


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is InventoryScreen.DragState and _item() == null \
			and Inventory.slot_accepts(slot, (data as InventoryScreen.DragState).item.definition)


func _drop_data(_at: Vector2, data: Variant) -> void:
	screen.component.request_equip((data as InventoryScreen.DragState).item.uuid, slot)
	screen.end_drag()
