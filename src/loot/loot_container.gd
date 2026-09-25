class_name LootContainer
extends StaticBody3D
## Contenedor de loot de un POI (nevera, taquilla...). GDD §8.
## Se rellena una sola vez, la primera vez que un jugador entra en su radio (o lo abre),
## con un RNG derivado de la seed del mundo y de su id: misma seed, mismo loot.
## 🔶 Sin reposición: depende del ciclo de días (M5) y está abierta en el GDD (§18.3).

@export var table: LootTable
@export var display_name: String = "Contenedor"
@export var grid_size: Vector2i = Vector2i(4, 4)
@export var box_size: Vector3 = Vector3(0.6, 1.0, 0.5)
@export var color: Color = Color(0.6, 0.6, 0.6)
## Distancia a un jugador a la que se rellena.
@export var fill_radius_m: float = 35.0

## Los asigna WorldBuilder al instanciar el POI. Por defecto: tier 1, sin bioma.
var container_id: StringName = &""
var poi_tier: int = 1
var biome_id: StringName = &""

var item_container: ItemContainer
var is_filled: bool = false

var _check_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"loot_container")
	collision_layer = PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLES
	_build_visual()


func _physics_process(delta: float) -> void:
	if is_filled or not multiplayer.is_server():
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.5
	for player: Node in get_tree().get_nodes_in_group(&"player"):
		if (player as Node3D).global_position.distance_to(global_position) <= fill_radius_m:
			fill()
			return


## Crea el contenedor y lo rellena con su tabla. Solo una vez y solo en el host.
func fill() -> void:
	if is_filled or not multiplayer.is_server():
		return
	is_filled = true
	if container_id == &"":
		container_id = StringName("loot_%d" % hash(get_path()))
	item_container = ItemContainer.new(container_id, [grid_size])
	if table == null:
		return
	var rng: RandomNumberGenerator = SeedUtil.make_rng(GameState.world_seed, StringName("loot:%s" % container_id))
	for item: ItemInstance in LootRoller.roll(table, poi_tier, biome_id, rng):
		if item.definition.weapon != null:
			item.state["rounds"] = 0
		item_container.insert_anywhere(item)


func interaction_text() -> String:
	return "Abrir %s" % display_name


## Host: abre el contenedor en el inventario del jugador.
func interact(player: Player) -> void:
	fill()
	player.inventory.open_external(item_container, self, display_name)


func _build_visual() -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	mesh_node.position.y = box_size.y * 0.5
	add_child(mesh_node)
	var shape := BoxShape3D.new()
	shape.size = box_size
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	shape_node.position.y = box_size.y * 0.5
	add_child(shape_node)
