class_name Inventory
extends RefCounted
## Inventario de un personaje (GDD §7.2): slots de equipo, bolsillos y las rejillas que
## aportan el rig y la mochila. Modelo puro: no sabe de red ni de UI. Las operaciones
## validan y devuelven false si no son legales; InventoryComponent las expone al host.

signal changed()

enum Slot { HELMET, TORSO, BACKPACK, PRIMARY, SECONDARY, PISTOL, MELEE }

const SLOT_PREFIX: String = "slot:"
const POCKETS_ID: StringName = &"pockets"

var profile: InventoryProfile
var pockets: ItemContainer
var equipped: Dictionary[Slot, ItemInstance] = {}
## Contenedores externos accesibles ahora (caja de loot abierta, suelo). id -> contenedor.
var external: Dictionary[StringName, ItemContainer] = {}


func _init(inventory_profile: InventoryProfile) -> void:
	profile = inventory_profile
	pockets = ItemContainer.new(POCKETS_ID, inventory_profile.pockets)


static func slot_target(slot: Slot) -> StringName:
	return StringName(SLOT_PREFIX + Slot.keys()[slot])


## True si el objeto puede ir en ese slot de equipo.
static func slot_accepts(slot: Slot, def: ItemDefinition) -> bool:
	match slot:
		Slot.HELMET:
			return def.armor != null and def.armor.protected_zones.has(BodyZones.Zone.HEAD)
		Slot.TORSO:
			# "Chaleco o rig" (GDD §7.2): armadura de tórax o rig de almacenamiento.
			return (def.category == ItemDefinition.Category.RIG
					or def.armor != null and def.armor.protected_zones.has(BodyZones.Zone.THORAX))
		Slot.BACKPACK:
			return def.category == ItemDefinition.Category.BACKPACK
		Slot.PRIMARY, Slot.SECONDARY:
			return def.weapon != null and def.weapon.slot in [WeaponDefinition.Slot.PRIMARY, WeaponDefinition.Slot.SECONDARY]
		Slot.PISTOL:
			return def.weapon != null and def.weapon.slot == WeaponDefinition.Slot.PISTOL
		Slot.MELEE:
			return def.weapon != null and def.weapon.slot == WeaponDefinition.Slot.MELEE
	return false


func item_in(slot: Slot) -> ItemInstance:
	return equipped.get(slot) as ItemInstance


## Contenedores donde el personaje guarda cosas: bolsillos, rig y mochila (en ese orden).
func storage() -> Array[ItemContainer]:
	var result: Array[ItemContainer] = [pockets]
	for slot: Slot in [Slot.TORSO, Slot.BACKPACK]:
		var item: ItemInstance = item_in(slot)
		if item != null and item.contents != null:
			result.append(item.contents)
	return result


## Contenedor por id: bolsillos, contenidos de objetos (a cualquier profundidad) o externos.
func container_by_id(id: StringName) -> ItemContainer:
	if external.has(id):
		return external[id]
	var roots: Array[ItemContainer] = storage()
	roots.append_array(external.values())
	for root: ItemContainer in roots:
		var found: ItemContainer = _find_container(root, id)
		if found != null:
			return found
	return null


func _find_container(root: ItemContainer, id: StringName) -> ItemContainer:
	if root.id == id:
		return root
	for item: ItemInstance in root.items():
		if item.contents != null:
			var found: ItemContainer = _find_container(item.contents, id)
			if found != null:
				return found
	return null


## Busca un objeto por uuid en equipo, almacenamiento y contenedores externos.
func find(uuid: StringName) -> ItemInstance:
	for slot: Slot in equipped:
		var item: ItemInstance = equipped[slot]
		if item.uuid == uuid:
			return item
		if item.contents != null and item.contents.find(uuid) != null:
			return item.contents.find(uuid)
	var loose: Array[ItemContainer] = [pockets]
	loose.append_array(external.values())
	for container: ItemContainer in loose:
		var found: ItemInstance = container.find(uuid)
		if found != null:
			return found
	return null


func slot_of(item: ItemInstance) -> int:
	for slot: Slot in equipped:
		if equipped[slot] == item:
			return slot
	return -1


## Saca el objeto de donde esté (contenedor o slot). Un objeto suelto ya está fuera.
func detach(item: ItemInstance) -> bool:
	var slot: int = slot_of(item)
	if slot >= 0:
		equipped.erase(slot)
		return true
	var container: ItemContainer = item.location()
	return container == null or container.remove(item)


## Mueve un objeto a un contenedor/rejilla/celda. Valida antes de tocar nada.
func move_to_container(item: ItemInstance, target: ItemContainer, grid: int, cell: Vector2i, rotated: bool) -> bool:
	if not target.can_place(item, grid, cell, rotated):
		return false
	var origin: ItemContainer = item.location()
	var origin_spot: Dictionary = origin.locate(item) if origin != null else {}
	var slot: int = slot_of(item)
	if not detach(item):
		return false
	if target.place(item, grid, cell, rotated):
		changed.emit()
		return true
	_restore(item, origin, origin_spot, slot)
	return false


## Equipa un objeto en un slot vacío. Al equiparlo sale de cualquier contenedor.
func equip(item: ItemInstance, slot: Slot) -> bool:
	if item_in(slot) != null or not slot_accepts(slot, item.definition):
		return false
	if not detach(item):
		return false
	equipped[slot] = item
	changed.emit()
	return true


## Desequipa a la primera posición libre del almacenamiento. False si no cabe.
func unequip_to_storage(slot: Slot) -> bool:
	var item: ItemInstance = item_in(slot)
	if item == null:
		return false
	equipped.erase(slot)
	for container: ItemContainer in storage():
		if container.insert_anywhere(item):
			changed.emit()
			return true
	equipped[slot] = item
	return false


## Guarda un objeto suelto (del suelo, recién creado) en el almacenamiento: primero
## rellena stacks existentes y luego busca hueco. Devuelve las unidades que no caben.
func store(item: ItemInstance) -> int:
	for container: ItemContainer in storage():
		if container.merge_into_stacks(item) == 0:
			changed.emit()
			return 0
	for container: ItemContainer in storage():
		if container.insert_anywhere(item):
			changed.emit()
			return 0
	changed.emit()
	return item.quantity


## Divide un stack y coloca la parte nueva en la posición dada.
func split_to(item: ItemInstance, amount: int, target: ItemContainer, grid: int, cell: Vector2i, rotated: bool) -> bool:
	if amount <= 0 or amount >= item.quantity:
		return false
	var probe := ItemInstance.new(item.definition, amount, &"__probe")
	if not target.can_place(probe, grid, cell, rotated):
		return false
	var part: ItemInstance = item.split(amount)
	target.place(part, grid, cell, rotated)
	changed.emit()
	return true


## Une `source` en `target` (mismo tipo apilable). Si `source` se vacía, desaparece.
func merge(source: ItemInstance, target: ItemInstance) -> bool:
	if target.merge_from(source) <= 0:
		return false
	if source.quantity <= 0:
		detach(source)
	changed.emit()
	return true


## Saca munición de los stacks del almacenamiento. Devuelve cuántas balas ha sacado.
func take_ammo(ammo_id: StringName, amount: int) -> int:
	var taken: int = 0
	for container: ItemContainer in storage():
		taken += _take_ammo_from(container, ammo_id, amount - taken)
		if taken >= amount:
			break
	if taken > 0:
		changed.emit()
	return taken


func _take_ammo_from(container: ItemContainer, ammo_id: StringName, wanted: int) -> int:
	var taken: int = 0
	for item: ItemInstance in container.items():
		if taken >= wanted:
			break
		if item.contents != null:
			taken += _take_ammo_from(item.contents, ammo_id, wanted - taken)
		elif item.definition.ammo != null and item.definition.ammo.id == ammo_id:
			var used: int = mini(item.quantity, wanted - taken)
			item.quantity -= used
			taken += used
			if item.quantity <= 0:
				container.remove(item)
	return taken


func count_ammo(ammo_id: StringName) -> int:
	var total: int = 0
	for container: ItemContainer in storage():
		total += container.count_ammo(ammo_id)
	return total


func total_weight() -> float:
	var total: float = pockets.total_weight()
	for slot: Slot in equipped:
		total += equipped[slot].weight_kg()
	return total


## Multiplicador de velocidad por peso: 1 hasta el umbral, baja linealmente hasta la sobrecarga.
func speed_multiplier() -> float:
	var t: float = inverse_lerp(profile.weight_penalty_start_kg, profile.weight_max_kg, total_weight())
	return lerpf(1.0, profile.overweight_speed_multiplier, clampf(t, 0.0, 1.0))


# Devuelve el objeto a donde estaba si una operación falla a medias.
func _restore(item: ItemInstance, origin: ItemContainer, spot: Dictionary, slot: int) -> void:
	if slot >= 0:
		equipped[slot] = item
	elif origin != null and not spot.is_empty():
		origin.place(item, spot.grid as int, spot.cell as Vector2i, spot.rotated as bool)
