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

@export var profile: InventoryProfile
## Peer dueño de este personaje (1 = host).
@export var owner_peer_id: int = 1

var inventory: Inventory


func _ready() -> void:
	inventory = Inventory.new(profile)
	inventory.changed.connect(inventory_changed.emit)


# --- Contenedores externos (los abre el host al interactuar) ---

func open_external(container: ItemContainer) -> void:
	inventory.external[container.id] = container
	inventory_changed.emit()


func close_external(container_id: StringName) -> void:
	if inventory.external.erase(container_id):
		inventory_changed.emit()


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
