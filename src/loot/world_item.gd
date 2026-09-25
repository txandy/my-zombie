class_name WorldItem
extends RigidBody3D
## Objeto suelto en el mundo (tirado desde el inventario). Se recoge con E.
## Cae y reposa sobre el mundo; no bloquea al jugador ni a las balas.

## Tamaño visual de una celda de inventario (m).
const CELL_SIZE_M: float = 0.12

var item: ItemInstance


## Crea un WorldItem para el objeto en `position`. En el mundo va por WorldItems (se
## replica a los clientes); sin él (escenas de pruebas) se añade a `parent`.
static func spawn(source: ItemInstance, position: Vector3, parent: Node) -> WorldItem:
	var root := parent.get_tree().get_first_node_in_group(&"world_items_root") as WorldItems
	if root != null:
		return root.drop_instance(source, position)
	var node := WorldItem.new()
	node.item = source
	parent.add_child(node)
	node.global_position = position
	return node


func _ready() -> void:
	add_to_group(&"world_item")
	NetSync.add(self, [":position", ":rotation"], 1)
	# Solo el host simula la física; en los clientes sigue la sincronización.
	freeze = not multiplayer.is_server()
	collision_layer = PhysicsLayers.INTERACTABLES
	collision_mask = PhysicsLayers.WORLD
	mass = maxf(item.weight_kg(), 0.1)
	var size := Vector3(item.definition.size.x * CELL_SIZE_M, 0.08, item.definition.size.y * CELL_SIZE_M)
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = item.definition.icon_color
	mesh.material = material
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	add_child(mesh_node)
	var shape := BoxShape3D.new()
	shape.size = size
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	add_child(shape_node)


func interaction_text() -> String:
	var amount: String = " (%d)" % item.quantity if item.quantity > 1 else ""
	return "Recoger %s%s" % [item.definition.display_name, amount]


## Host: intenta guardar el objeto en el inventario del jugador.
func interact(player: Player) -> void:
	if player.inventory.give(item) == 0:
		queue_free()
