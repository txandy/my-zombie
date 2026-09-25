class_name InventoryComponent
extends Node
## Inventario de un personaje en el mundo. El dueño (o su UI) pide operaciones con
## request_*(); el host valida y aplica sobre el modelo Inventory (GDD §7.3, AGENTS.md §4).
##
## Validaciones del host: el emisor es el dueño, el objeto está a su alcance (equipo,
## almacenamiento o un contenedor externo abierto) y el destino también.
## 🔶 La replicación del estado a los clientes llega en M7; ahora el host y la UI
## local comparten el mismo modelo.

## Host: el inventario ha cambiado (UI, armadura, armas, peso).
signal inventory_changed()
## Host: el dueño ha tirado un objeto; el mundo debe crear su pickup en el suelo.
signal item_dropped(item: ItemInstance)
## Host: una operación pedida se ha rechazado (para feedback en la UI).
signal request_rejected(reason: String)
## Se ha abierto un contenedor externo (la UI abre el inventario al lado).
signal external_opened(container: ItemContainer, title: String)

@export var profile: InventoryProfile
## Peer dueño de este personaje (1 = host).
@export var owner_peer_id: int = 1
## Distancia a partir de la cual se cierra un contenedor externo abierto.
@export var external_max_distance_m: float = 3.5

var inventory: Inventory
## Uso rápido: tecla (4-0) -> uuid del objeto (GDD §7.2).
var quick_bindings: Dictionary[int, StringName] = {}
## Nodo del mundo de cada contenedor externo abierto (para cerrarlo al alejarse).
var _external_sources: Dictionary[StringName, Node3D] = {}


func _ready() -> void:
	inventory = Inventory.new(profile)
	inventory.changed.connect(inventory_changed.emit)


# --- Contenedores externos (los abre el host al interactuar) ---

func open_external(container: ItemContainer, source: Node3D = null, title: String = "") -> void:
	inventory.external[container.id] = container
	if source != null:
		_external_sources[container.id] = source
	inventory_changed.emit()
	if title == "" and source != null:
		title = String(source.name)
	external_opened.emit(container, title)


func close_external(container_id: StringName) -> void:
	_external_sources.erase(container_id)
	if inventory.external.erase(container_id):
		inventory_changed.emit()


func _physics_process(_delta: float) -> void:
	if _external_sources.is_empty():
		return
	var me := get_parent() as Node3D
	if me == null:
		return
	for id: StringName in _external_sources.keys():
		var source: Node3D = _external_sources[id]
		if not is_instance_valid(source) or me.global_position.distance_to(source.global_position) > external_max_distance_m:
			close_external(id)


# --- Solicitudes (dueño -> host) ---

func request_move(item_uuid: StringName, target_id: StringName, grid: int, cell: Vector2i, rotated: bool) -> void:
	_server_move.rpc_id(1, item_uuid, target_id, grid, cell, rotated)


func request_equip(item_uuid: StringName, slot: Inventory.Slot) -> void:
	_server_equip.rpc_id(1, item_uuid, slot)


func request_unequip(slot: Inventory.Slot) -> void:
	_server_unequip.rpc_id(1, slot)


func request_split(item_uuid: StringName, amount: int, target_id: StringName, grid: int, cell: Vector2i, rotated: bool) -> void:
	_server_split.rpc_id(1, item_uuid, amount, target_id, grid, cell, rotated)


func request_merge(source_uuid: StringName, target_uuid: StringName) -> void:
	_server_merge.rpc_id(1, source_uuid, target_uuid)


func request_drop(item_uuid: StringName) -> void:
	_server_drop.rpc_id(1, item_uuid)


func request_use(item_uuid: StringName) -> void:
	_server_use.rpc_id(1, item_uuid)


## Transferencia rápida: de un contenedor externo al inventario, o del inventario al
## contenedor externo abierto (si hay uno).
func request_quick_move(item_uuid: StringName) -> void:
	_server_quick_move.rpc_id(1, item_uuid)


## Asigna un objeto a una tecla de uso rápido (4-0). Uuid vacío = quitar.
func request_bind_quick(key: int, item_uuid: StringName) -> void:
	_server_bind_quick.rpc_id(1, key, item_uuid)


## Cierra los contenedores externos abiertos (al cerrar la pantalla de inventario).
func request_close_externals() -> void:
	_server_close_externals.rpc_id(1)


func request_use_quick(key: int) -> void:
	var uuid: StringName = quick_bindings.get(key, &"")
	if uuid != &"":
		request_use(uuid)


@rpc("any_peer", "call_local", "reliable")
func _server_move(item_uuid: StringName, target_id: StringName, grid: int, cell: Vector2i, rotated: bool) -> void:
	var item: ItemInstance = _validated_item(item_uuid)
	var target: ItemContainer = inventory.container_by_id(target_id) if item != null else null
	if target == null:
		_reject("destino no disponible")
	elif not inventory.move_to_container(item, target, grid, cell, rotated):
		_reject("no cabe ahí")


@rpc("any_peer", "call_local", "reliable")
func _server_equip(item_uuid: StringName, slot: Inventory.Slot) -> void:
	var item: ItemInstance = _validated_item(item_uuid)
	if item != null and not inventory.equip(item, slot):
		_reject("no se puede equipar ahí")


@rpc("any_peer", "call_local", "reliable")
func _server_unequip(slot: Inventory.Slot) -> void:
	if _is_valid_sender() and not inventory.unequip_to_storage(slot):
		_reject("no hay sitio para guardarlo")


@rpc("any_peer", "call_local", "reliable")
func _server_split(item_uuid: StringName, amount: int, target_id: StringName, grid: int, cell: Vector2i, rotated: bool) -> void:
	var item: ItemInstance = _validated_item(item_uuid)
	var target: ItemContainer = inventory.container_by_id(target_id) if item != null else null
	if target == null or not inventory.split_to(item, amount, target, grid, cell, rotated):
		_reject("no se puede dividir ahí")


@rpc("any_peer", "call_local", "reliable")
func _server_merge(source_uuid: StringName, target_uuid: StringName) -> void:
	var source: ItemInstance = _validated_item(source_uuid)
	var target: ItemInstance = _validated_item(target_uuid) if source != null else null
	if target == null or not inventory.merge(source, target):
		_reject("no se pueden unir")


@rpc("any_peer", "call_local", "reliable")
func _server_drop(item_uuid: StringName) -> void:
	var item: ItemInstance = _validated_item(item_uuid)
	if item != null and inventory.detach(item):
		inventory_changed.emit()
		item_dropped.emit(item)


@rpc("any_peer", "call_local", "reliable")
func _server_use(item_uuid: StringName) -> void:
	var item: ItemInstance = _validated_item(item_uuid)
	if item == null:
		return
	var effect: ItemUseEffect = item.definition.use_effect
	if effect == null or not effect.can_apply(get_parent()):
		_reject("no tiene efecto ahora")
		return
	if effect.apply(get_parent()):
		item.quantity -= 1
		if item.quantity <= 0:
			inventory.detach(item)
		inventory_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _server_quick_move(item_uuid: StringName) -> void:
	var item: ItemInstance = _validated_item(item_uuid)
	if item == null:
		return
	var origin: ItemContainer = item.location()
	var from_external: bool = origin != null and _is_in_external(origin)
	if from_external:
		var spot: Dictionary = origin.locate(item)
		origin.remove(item)
		if inventory.store(item) > 0:
			origin.place(item, spot.grid as int, spot.cell as Vector2i, spot.rotated as bool)
			_reject("no cabe en el inventario")
		return
	for target: ItemContainer in inventory.external.values():
		if target.can_hold(item) and _has_free_spot(target, item) and inventory.detach(item):
			target.insert_anywhere(item)
			inventory_changed.emit()
			return
	_reject("no hay sitio")


@rpc("any_peer", "call_local", "reliable")
func _server_close_externals() -> void:
	if not _is_valid_sender():
		return
	for id: StringName in inventory.external.keys():
		close_external(id)


@rpc("any_peer", "call_local", "reliable")
func _server_bind_quick(key: int, item_uuid: StringName) -> void:
	if not _is_valid_sender() or key < 4 or key > 10:
		return
	if item_uuid == &"":
		quick_bindings.erase(key)
	elif inventory.find(item_uuid) != null:
		quick_bindings[key] = item_uuid
	inventory_changed.emit()


static func _has_free_spot(container: ItemContainer, item: ItemInstance) -> bool:
	for grid: ItemGrid in container.grids:
		if not grid.find_free_spot(item).is_empty():
			return true
	return false


# True si el contenedor es externo o está dentro de uno externo.
func _is_in_external(container: ItemContainer) -> bool:
	while container != null:
		if inventory.external.has(container.id):
			return true
		var holder: ItemInstance = container.owner_item()
		container = holder.location() if holder != null else null
	return false


## Host: añade un objeto nuevo al almacenamiento (loot recogido, reparto inicial).
## Devuelve las unidades que no caben.
func give(item: ItemInstance) -> int:
	if not multiplayer.is_server():
		return item.quantity
	return inventory.store(item)


func _validated_item(item_uuid: StringName) -> ItemInstance:
	if not _is_valid_sender():
		return null
	var item: ItemInstance = inventory.find(item_uuid)
	if item == null:
		_reject("objeto fuera de alcance")
	return item


func _is_valid_sender() -> bool:
	if not multiplayer.is_server():
		return false
	var sender: int = multiplayer.get_remote_sender_id()
	return sender == owner_peer_id or (sender == 0 and owner_peer_id == multiplayer.get_unique_id())


func _reject(reason: String) -> void:
	request_rejected.emit(reason)


# --- Proveedor de munición para WeaponHolder (host) ---

func count_ammo(ammo_id: StringName) -> int:
	return inventory.count_ammo(ammo_id)


func take_ammo(ammo_id: StringName, amount: int) -> int:
	return inventory.take_ammo(ammo_id, amount)


## Tipos de munición del calibre que hay en el almacenamiento, en orden de aparición.
func ammo_types_for(caliber: StringName) -> Array[AmmoDefinition]:
	var result: Array[AmmoDefinition] = []
	for container: ItemContainer in inventory.storage():
		_collect_ammo_types(container, caliber, result)
	return result


func _collect_ammo_types(container: ItemContainer, caliber: StringName, result: Array[AmmoDefinition]) -> void:
	for item: ItemInstance in container.items():
		var ammo: AmmoDefinition = item.definition.ammo
		if ammo != null and ammo.caliber == caliber and not result.has(ammo):
			result.append(ammo)
		if item.contents != null:
			_collect_ammo_types(item.contents, caliber, result)


## Devuelve balas al inventario (al descargar un arma). Lo que no cabe se tira al suelo.
func return_ammo(ammo: AmmoDefinition, amount: int) -> void:
	var def: ItemDefinition = ItemCatalog.load_default().item_for_ammo(ammo)
	if def == null or amount <= 0:
		return
	while amount > 0:
		var stack := ItemInstance.new(def, mini(amount, def.max_stack))
		amount -= stack.quantity
		if inventory.store(stack) > 0:
			item_dropped.emit(stack)


## Host: crea y reparte un kit inicial. Las armas vienen cargadas con su munición por defecto.
func apply_kit(kit: StartingKit) -> void:
	if not multiplayer.is_server() or kit == null:
		return
	var to_store: Array[ItemInstance] = []
	for entry: KitEntry in kit.entries:
		var item := ItemInstance.new(entry.item, entry.quantity)
		if entry.item.weapon != null:
			WeaponHolder.load_full(item)
		if entry.slot >= 0:
			inventory.equip(item, entry.slot as Inventory.Slot)
		else:
			to_store.append(item)
	for item: ItemInstance in to_store:
		if inventory.store(item) > 0:
			item_dropped.emit(item)


## Host: genera el equipo de un NPC con sus tablas de loot (GDD §8). Las armas vienen
## cargadas y se añaden cargadores de repuesto de su munición.
func apply_loadout(loadout: NPCLoadout, rng: RandomNumberGenerator, tier: int = 1, biome_id: StringName = &"") -> void:
	if not multiplayer.is_server() or loadout == null:
		return
	var slots: Dictionary[Inventory.Slot, LootTable] = {
		Inventory.Slot.TORSO: loadout.torso, Inventory.Slot.BACKPACK: loadout.backpack,
		Inventory.Slot.HELMET: loadout.helmet, Inventory.Slot.PRIMARY: loadout.primary,
		Inventory.Slot.PISTOL: loadout.pistol, Inventory.Slot.MELEE: loadout.melee,
	}
	# Primero rig y mochila: así el resto tiene dónde guardarse.
	for slot: Inventory.Slot in slots:
		if slots[slot] == null:
			continue
		for item: ItemInstance in LootRoller.roll(slots[slot], tier, biome_id, rng):
			if item.definition.weapon != null:
				WeaponHolder.load_full(item)
			if not inventory.equip(item, slot):
				inventory.store(item)
	for weapon_slot: Inventory.Slot in [Inventory.Slot.PRIMARY, Inventory.Slot.PISTOL]:
		var weapon_item: ItemInstance = inventory.item_in(weapon_slot)
		if weapon_item != null and weapon_item.definition.weapon.kind == WeaponDefinition.Kind.FIREARM:
			var weapon: WeaponDefinition = weapon_item.definition.weapon
			return_ammo(weapon.default_ammo, weapon.magazine_size * loadout.spare_magazines)
	if loadout.storage != null:
		for item: ItemInstance in LootRoller.roll(loadout.storage, tier, biome_id, rng):
			inventory.store(item)
