class_name ItemContainer
extends RefCounted
## Contenedor con una o varias rejillas (GDD §7.1-7.2). Puede pertenecer a un objeto
## (mochila, rig) o ser independiente (bolsillos, caja de loot del mundo).
## Un contenedor no puede meterse dentro de sí mismo ni de sus descendientes.

var id: StringName
var grids: Array[ItemGrid] = []

var _owner_item: WeakRef


func _init(container_id: StringName, grid_sizes: Array[Vector2i], owner: ItemInstance = null) -> void:
	id = container_id
	for size: Vector2i in grid_sizes:
		grids.append(ItemGrid.new(size))
	_owner_item = weakref(owner) if owner != null else null


## Objeto al que pertenece (mochila, rig) o null.
func owner_item() -> ItemInstance:
	return _owner_item.get_ref() as ItemInstance if _owner_item != null else null


## True si el objeto puede entrar aquí sin crear un ciclo (meterse en sí mismo o en un hijo).
func can_hold(item: ItemInstance) -> bool:
	var holder: ItemInstance = owner_item()
	return holder == null or not item.contains_or_is(holder)


func can_place(item: ItemInstance, grid_index: int, cell: Vector2i, rotated: bool) -> bool:
	if grid_index < 0 or grid_index >= grids.size() or not can_hold(item):
		return false
	var ignore: ItemInstance = item if item.location() == self else null
	return grids[grid_index].can_place(item, cell, rotated, ignore)


## Coloca el objeto (que no debe estar en ningún contenedor) en la rejilla y celda dadas.
func place(item: ItemInstance, grid_index: int, cell: Vector2i, rotated: bool) -> bool:
	if item.location() != null or not can_place(item, grid_index, cell, rotated):
		return false
	if not grids[grid_index].place(item, cell, rotated):
		return false
	item.set_location(self)
	return true


func remove(item: ItemInstance) -> bool:
	if item.location() != self:
		return false
	for grid: ItemGrid in grids:
		if grid.remove(item):
			item.set_location(null)
			return true
	return false


## Coloca el objeto en el primer hueco libre de cualquier rejilla.
func insert_anywhere(item: ItemInstance) -> bool:
	if item.location() != null or not can_hold(item):
		return false
	for g: int in grids.size():
		var spot: Dictionary = grids[g].find_free_spot(item)
		if not spot.is_empty():
			return place(item, g, spot.cell as Vector2i, spot.rotated as bool)
	return false


## Une el objeto a stacks compatibles que ya haya aquí. Devuelve las unidades que quedan.
func merge_into_stacks(item: ItemInstance) -> int:
	for existing: ItemInstance in items():
		if item.quantity <= 0:
			break
		existing.merge_from(item)
	return item.quantity


## Rejilla y entrada del objeto en este contenedor, o {} si no está aquí.
func locate(item: ItemInstance) -> Dictionary:
	for g: int in grids.size():
		var entry: ItemGrid.Entry = grids[g].entry_of(item)
		if entry != null:
			return {"grid": g, "cell": entry.cell, "rotated": entry.rotated}
	return {}


## Objetos directamente en este contenedor (sin entrar en los anidados).
func items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for grid: ItemGrid in grids:
		for entry: ItemGrid.Entry in grid.entries():
			result.append(entry.item)
	return result


## Busca un objeto por uuid aquí y en los contenedores anidados.
func find(uuid: StringName) -> ItemInstance:
	for item: ItemInstance in items():
		if item.uuid == uuid:
			return item
		if item.contents != null:
			var nested: ItemInstance = item.contents.find(uuid)
			if nested != null:
				return nested
	return null


func total_weight() -> float:
	var total: float = 0.0
	for item: ItemInstance in items():
		total += item.weight_kg()
	return total


## Unidades de munición con ese id en este contenedor y los anidados.
func count_ammo(ammo_id: StringName) -> int:
	var total: int = 0
	for item: ItemInstance in items():
		if item.definition.ammo != null and item.definition.ammo.id == ammo_id:
			total += item.quantity
		if item.contents != null:
			total += item.contents.count_ammo(ammo_id)
	return total
