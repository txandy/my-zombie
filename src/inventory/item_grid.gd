class_name ItemGrid
extends RefCounted
## Rejilla de un contenedor: matriz de ocupación (GDD §7.1-7.2).
## Colocar exige que todas las celdas de la huella (ya rotada) estén libres.


class Entry:
	extends RefCounted
	var item: ItemInstance
	var cell: Vector2i
	var rotated: bool

	func _init(i: ItemInstance, c: Vector2i, r: bool) -> void:
		item = i
		cell = c
		rotated = r

	func rect() -> Rect2i:
		return Rect2i(cell, item.definition.footprint(rotated))


var width: int = 0
var height: int = 0

## uuid del objeto que ocupa cada celda (&"" si está libre). Índice = y * width + x.
var _cells: Array[StringName] = []
var _entries: Dictionary[StringName, Entry] = {}


func _init(size: Vector2i) -> void:
	width = size.x
	height = size.y
	_cells.resize(width * height)
	_cells.fill(&"")


func entries() -> Array[Entry]:
	var result: Array[Entry] = []
	for entry: Entry in _entries.values():
		result.append(entry)
	return result


func entry_of(item: ItemInstance) -> Entry:
	return _entries.get(item.uuid) as Entry


func item_at(cell: Vector2i) -> ItemInstance:
	if not Rect2i(Vector2i.ZERO, Vector2i(width, height)).has_point(cell):
		return null
	var id: StringName = _cells[cell.y * width + cell.x]
	return (_entries[id] as Entry).item if id != &"" else null


## True si el objeto cabe en `cell` con esa rotación. `ignore` permite recolocar un objeto
## sobre sus propias celdas (rotarlo o moverlo dentro de la misma rejilla).
func can_place(item: ItemInstance, cell: Vector2i, rotated: bool, ignore: ItemInstance = null) -> bool:
	if rotated and not item.definition.rotatable:
		return false
	var rect := Rect2i(cell, item.definition.footprint(rotated))
	if not Rect2i(Vector2i.ZERO, Vector2i(width, height)).encloses(rect):
		return false
	var ignored: StringName = ignore.uuid if ignore != null else &""
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var occupant: StringName = _cells[y * width + x]
			if occupant != &"" and occupant != ignored:
				return false
	return true


func place(item: ItemInstance, cell: Vector2i, rotated: bool) -> bool:
	if _entries.has(item.uuid) or not can_place(item, cell, rotated):
		return false
	var entry := Entry.new(item, cell, rotated)
	_entries[item.uuid] = entry
	_fill(entry.rect(), item.uuid)
	return true


func remove(item: ItemInstance) -> bool:
	var entry: Entry = _entries.get(item.uuid) as Entry
	if entry == null:
		return false
	_fill(entry.rect(), &"")
	_entries.erase(item.uuid)
	return true


## Primera celda libre (recorriendo filas) donde cabe el objeto: sin rotar y, si no, rotado.
## Devuelve {"cell": Vector2i, "rotated": bool} o un diccionario vacío.
func find_free_spot(item: ItemInstance) -> Dictionary:
	for rotated: bool in [false, true]:
		if rotated and (not item.definition.rotatable or item.definition.size.x == item.definition.size.y):
			continue
		for y: int in height:
			for x: int in width:
				if can_place(item, Vector2i(x, y), rotated):
					return {"cell": Vector2i(x, y), "rotated": rotated}
	return {}


func free_cells() -> int:
	return _cells.count(&"")


func _fill(rect: Rect2i, id: StringName) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_cells[y * width + x] = id
