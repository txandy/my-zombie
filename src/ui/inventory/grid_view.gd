class_name GridView
extends Control
## Dibuja una rejilla de un contenedor y sus objetos, y gestiona arrastrar y soltar.
## Solo presentación: toda acción se pide al InventoryComponent (AGENTS.md §4).

const CELL_PX: int = 44

var screen: InventoryScreen
var container: ItemContainer
var grid_index: int = 0

## Celda y validez de la previsualización al arrastrar encima.
var _hover_cell := Vector2i(-1, -1)
var _hover_ok: bool = false


func setup(owner_screen: InventoryScreen, source: ItemContainer, index: int) -> void:
	screen = owner_screen
	container = source
	grid_index = index
	var grid: ItemGrid = source.grids[index]
	custom_minimum_size = Vector2(grid.width * CELL_PX, grid.height * CELL_PX)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _grid() -> ItemGrid:
	return container.grids[grid_index]


func _draw() -> void:
	var grid: ItemGrid = _grid()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.1, 0.9))
	for y: int in grid.height:
		for x: int in grid.width:
			draw_rect(Rect2(Vector2(x, y) * CELL_PX, Vector2.ONE * CELL_PX), Color(0.3, 0.32, 0.34), false, 1.0)
	for entry: ItemGrid.Entry in grid.entries():
		screen.draw_item(self, entry.item, Rect2(Vector2(entry.cell) * CELL_PX,
				Vector2(entry.item.definition.footprint(entry.rotated)) * CELL_PX))
	if _hover_cell.x >= 0 and screen.drag != null:
		var footprint: Vector2i = screen.drag.item.definition.footprint(screen.drag.rotated)
		var tint: Color = Color(0.3, 0.9, 0.4, 0.35) if _hover_ok else Color(0.95, 0.3, 0.25, 0.35)
		draw_rect(Rect2(Vector2(_hover_cell) * CELL_PX, Vector2(footprint) * CELL_PX), tint)


func item_at_position(at: Vector2) -> ItemInstance:
	return _grid().item_at(Vector2i(floori(at.x / CELL_PX), floori(at.y / CELL_PX)))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		var item: ItemInstance = item_at_position(button.position)
		if item != null:
			screen.on_item_clicked(item, button)
	var motion := event as InputEventMouseMotion
	if motion != null:
		screen.set_hovered(item_at_position(motion.position))


func _get_drag_data(at: Vector2) -> Variant:
	var item: ItemInstance = item_at_position(at)
	if item == null:
		return null
	var entry: ItemGrid.Entry = _grid().entry_of(item)
	var grab := Vector2i(floori(at.x / CELL_PX), floori(at.y / CELL_PX)) - entry.cell
	return screen.begin_drag(item, entry.rotated, grab)


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is InventoryScreen.DragState:
		return false
	var drag := data as InventoryScreen.DragState
	_hover_cell = Vector2i(floori(at.x / CELL_PX), floori(at.y / CELL_PX)) - drag.grab_cell()
	var target: ItemInstance = item_at_position(at)
	_hover_ok = (target != null and target.can_stack_with(drag.item)) or \
			container.can_place(drag.item, grid_index, _hover_cell, drag.rotated)
	queue_redraw()
	return true


func _drop_data(at: Vector2, data: Variant) -> void:
	var drag := data as InventoryScreen.DragState
	var target: ItemInstance = item_at_position(at)
	_clear_hover()
	if target != null and target.can_stack_with(drag.item) and drag.split_amount <= 0:
		screen.component.request_merge(drag.item.uuid, target.uuid)
	elif drag.split_amount > 0:
		screen.component.request_split(drag.item.uuid, drag.split_amount, container.id, grid_index,
				Vector2i(floori(at.x / CELL_PX), floori(at.y / CELL_PX)) - drag.grab_cell(), drag.rotated)
	else:
		screen.component.request_move(drag.item.uuid, container.id, grid_index,
				Vector2i(floori(at.x / CELL_PX), floori(at.y / CELL_PX)) - drag.grab_cell(), drag.rotated)
	screen.end_drag()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_clear_hover()


func _clear_hover() -> void:
	_hover_cell = Vector2i(-1, -1)
	queue_redraw()
