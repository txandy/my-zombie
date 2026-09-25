class_name WorldItems
extends Node3D
## Contenedor de los objetos sueltos en el mundo (GDD §7.2 tirar, §12 red). En el host
## los crea con un MultiplayerSpawner, así aparecen también en los clientes listos.

var _spawner: MultiplayerSpawner
var _serial: int = 0
## Objetos que el host está soltando: se conserva la misma instancia (uuid y estado).
var _pending: Dictionary[String, ItemInstance] = {}


func _ready() -> void:
	add_to_group(&"world_items_root")
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	_spawner.spawn_function = _spawn
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)


## Host: crea un objeto suelto en `position`.
func drop_instance(item: ItemInstance, position: Vector3) -> WorldItem:
	_serial += 1
	_pending[String(item.uuid)] = item
	return _spawner.spawn({"name": "WorldItem_%d" % _serial, "item": ItemSerializer.item_to_dict(item),
			"pos": position, "uuid": String(item.uuid)}) as WorldItem


func _spawn(data: Dictionary) -> Node:
	var node := WorldItem.new()
	node.name = String(data.name)
	var existing: ItemInstance = _pending.get(String(data.uuid)) as ItemInstance
	node.item = existing if existing != null else ItemSerializer.item_from_dict(data.item, ItemCatalog.load_default())
	_pending.erase(String(data.uuid))
	node.position = data.pos
	return node
