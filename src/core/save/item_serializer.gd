class_name ItemSerializer
## Convierte objetos, contenedores e inventarios a diccionarios de tipos básicos (y al
## revés) para guardarlos (GDD §13). Las definiciones se guardan por id (ItemCatalog)
## y las municiones cargadas por ruta de recurso.


static func item_to_dict(item: ItemInstance) -> Dictionary:
	var data: Dictionary = {"uuid": String(item.uuid), "def": String(item.definition.id),
			"qty": item.quantity, "dur": item.durability}
	var state: Dictionary = {}
	for key: Variant in item.state:
		var value: Variant = item.state[key]
		state[key] = (value as Resource).resource_path if value is Resource else value
	data["state"] = state
	if item.contents != null:
		data["contents"] = container_to_list(item.contents)
	return data


## Crea el objeto (y su contenido). Devuelve null si su definición ya no existe.
static func item_from_dict(data: Dictionary, catalog: ItemCatalog) -> ItemInstance:
	var def: ItemDefinition = catalog.get_item(StringName(data.def))
	if def == null:
		push_warning("Partida: objeto desconocido '%s', se descarta" % data.def)
		return null
	var uuid := StringName(data.uuid)
	var item := ItemInstance.new(def, int(data.qty), uuid)
	ItemInstance.reserve_serial(String(uuid).trim_prefix("item_").to_int())
	item.durability = float(data.dur)
	for key: Variant in data.state:
		var value: Variant = data.state[key]
		item.state[key] = load(value) if value is String and (value as String).begins_with("res://") else value
	if item.contents != null and data.has("contents"):
		container_from_list(item.contents, data.contents, catalog)
	return item


## Objetos de un contenedor con su posición: [{grid, cell, rot, item}].
static func container_to_list(container: ItemContainer) -> Array:
	var list: Array = []
	for g: int in container.grids.size():
		for entry: ItemGrid.Entry in container.grids[g].entries():
			list.append({"grid": g, "cell": entry.cell, "rot": entry.rotated, "item": item_to_dict(entry.item)})
	return list


static func container_from_list(container: ItemContainer, list: Array, catalog: ItemCatalog) -> void:
	for entry: Dictionary in list:
		var item: ItemInstance = item_from_dict(entry.item, catalog)
		if item != null and not container.place(item, int(entry.grid), entry.cell as Vector2i, bool(entry.rot)):
			container.insert_anywhere(item)


static func inventory_to_dict(component: InventoryComponent) -> Dictionary:
	var inv: Inventory = component.inventory
	var equipped: Dictionary = {}
	for slot: Inventory.Slot in inv.equipped:
		equipped[Inventory.Slot.keys()[slot]] = item_to_dict(inv.equipped[slot])
	var quick: Dictionary = {}
	for key: int in component.quick_bindings:
		quick[key] = String(component.quick_bindings[key])
	return {"equipped": equipped, "pockets": container_to_list(inv.pockets), "quick": quick}


## Sustituye el contenido del inventario por el guardado.
static func inventory_from_dict(component: InventoryComponent, data: Dictionary, catalog: ItemCatalog) -> void:
	var inv: Inventory = component.inventory
	for slot: Inventory.Slot in inv.equipped.keys():
		inv.equipped.erase(slot)
	for item: ItemInstance in inv.pockets.items():
		inv.pockets.remove(item)
	for slot_name: String in data.equipped:
		var item: ItemInstance = item_from_dict(data.equipped[slot_name], catalog)
		if item != null:
			inv.equipped[Inventory.Slot.get(slot_name) as Inventory.Slot] = item
	container_from_list(inv.pockets, data.pockets, catalog)
	component.quick_bindings.clear()
	for key: Variant in data.quick:
		component.quick_bindings[int(key)] = StringName(data.quick[key])
	component.inventory_changed.emit()


static func survival_to_dict(survival: SurvivalComponent) -> Dictionary:
	return {"hunger": survival.hunger, "thirst": survival.thirst, "temp": survival.body_temp_c,
			"stamina": survival.stamina}


static func survival_from_dict(survival: SurvivalComponent, data: Dictionary) -> void:
	survival.hunger = float(data.hunger)
	survival.thirst = float(data.thirst)
	survival.body_temp_c = float(data.temp)
	survival.stamina = float(data.stamina)
	survival.changed.emit()


## Contenedor completo (id, tamaño de sus rejillas y objetos), para enviarlo por red.
static func container_to_dict(container: ItemContainer) -> Dictionary:
	var sizes: Array = []
	for grid: ItemGrid in container.grids:
		sizes.append(Vector2i(grid.width, grid.height))
	return {"id": String(container.id), "grids": sizes, "items": container_to_list(container)}


static func container_from_dict(data: Dictionary, catalog: ItemCatalog) -> ItemContainer:
	var sizes: Array[Vector2i] = []
	for size: Variant in data.grids:
		sizes.append(size as Vector2i)
	var container := ItemContainer.new(StringName(data.id), sizes)
	container_from_list(container, data.items, catalog)
	return container
