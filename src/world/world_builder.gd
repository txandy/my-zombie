class_name WorldBuilder
extends Node3D
## Vuelca un WorldData en nodos: terreno (Terrain3D), mar, POIs y vegetación.
## No genera nada: todo sale de WorldData, así que el resultado es el mismo en todos los peers.

## Tamaño de los chunks de vegetación (m). Cada chunk es un MultiMesh por capa y un
## cuerpo de física, para que el frustum culling y la distancia de dibujado funcionen por zonas.
const VEGETATION_CHUNK_M: float = 128.0
## Hundimiento de la vegetación en el terreno para que no flote en pendientes.
const VEGETATION_SINK_M: float = 0.15
const SEA_COLOR := Color(0.1, 0.25, 0.35, 0.85)

var terrain: Terrain3D

var _physics_bodies: Array[RID] = []
var _collision_shapes: Array[Shape3D] = []


func _exit_tree() -> void:
	for body: RID in _physics_bodies:
		PhysicsServer3D.free_rid(body)
	_physics_bodies.clear()


func build(data: WorldData, settings: WorldGenSettings) -> void:
	_build_terrain(data, settings)
	_build_sea(data)
	_build_pois(data, settings)
	_build_vegetation(data, settings)


func _build_terrain(data: WorldData, settings: WorldGenSettings) -> void:
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = Terrain3D.SIZE_256
	terrain.vertex_spacing = data.cell_size_m
	terrain.material = Terrain3DMaterial.new()
	terrain.assets = Terrain3DAssets.new()
	# Sin texturas todavía: el colormap (color por bioma) hace de albedo.
	terrain.material.show_colormap = true
	terrain.collision.mode = Terrain3DCollision.FULL_GAME
	add_child(terrain)
	var n: int = data.resolution
	var heights := Image.create_from_data(n, n, false, Image.FORMAT_RF, data.heights.to_byte_array())
	terrain.data.import_images([heights, null, biome_color_image(data, settings)], Vector3.ZERO, 0.0, 1.0)


## Imagen del mapa de biomas (un píxel por muestra), sombreada con la altura.
## También sirve de base para el mapa del mundo (GDD §14).
static func biome_color_image(data: WorldData, settings: WorldGenSettings) -> Image:
	var n: int = data.resolution
	var colors: Array[Color] = []
	for biome: BiomeDefinition in settings.biomes:
		colors.append(biome.debug_color)
	var bytes := PackedByteArray()
	bytes.resize(n * n * 3)
	for i: int in n * n:
		var shade: float = clampf(0.8 + data.heights[i] * 0.004, 0.6, 1.2)
		var c: Color = colors[data.biomes[i]] * shade
		bytes[i * 3] = clampi(roundi(c.r * 255.0), 0, 255)
		bytes[i * 3 + 1] = clampi(roundi(c.g * 255.0), 0, 255)
		bytes[i * 3 + 2] = clampi(roundi(c.b * 255.0), 0, 255)
	return Image.create_from_data(n, n, false, Image.FORMAT_RGB8, bytes)


func _build_sea(data: WorldData) -> void:
	var size: float = data.resolution * data.cell_size_m
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size * 3.0
	var material := StandardMaterial3D.new()
	material.albedo_color = SEA_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	plane.material = material
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = Vector3(size * 0.5, 0.0, size * 0.5)
	add_child(sea)


func _build_pois(data: WorldData, settings: WorldGenSettings) -> void:
	var root := Node3D.new()
	root.name = "POIs"
	add_child(root)
	for poi: PoiPlacement in data.pois:
		var def: PoiDefinition = settings.poi_definitions[poi.definition_index]
		var instance: Node3D = (load(def.scene_path) as PackedScene).instantiate() as Node3D
		instance.name = "%s_%d" % [def.id, root.get_child_count()]
		instance.position = poi.position
		instance.rotation.y = poi.rotation_steps * PI * 0.5
		root.add_child(instance)
		_setup_loot(instance, def, _biome_at(data, settings, poi.position))


# Da a cada contenedor de loot del POI un id estable (POI + nodo), el tier y el bioma.
func _setup_loot(poi_node: Node, def: PoiDefinition, biome_id: StringName) -> void:
	for node: Node in poi_node.find_children("*", "", true, false):
		var container := node as LootContainer
		if container == null:
			continue
		container.container_id = StringName("%s/%s" % [poi_node.name, poi_node.get_path_to(container)])
		container.poi_tier = def.tier
		container.biome_id = biome_id


static func _biome_at(data: WorldData, settings: WorldGenSettings, point: Vector3) -> StringName:
	var x: int = clampi(roundi(point.x / data.cell_size_m), 0, data.resolution - 1)
	var z: int = clampi(roundi(point.z / data.cell_size_m), 0, data.resolution - 1)
	return settings.biomes[data.biomes[data.index(x, z)]].id


func _build_vegetation(data: WorldData, settings: WorldGenSettings) -> void:
	var root := Node3D.new()
	root.name = "Vegetation"
	add_child(root)
	var registry := CoverRegistry.new()
	registry.name = "CoverRegistry"
	add_child(registry)
	for l: int in data.vegetation.size():
		var layer: VegetationLayer = settings.vegetation_layers[l]
		var chunks: Dictionary[Vector2i, PackedInt32Array] = _group_by_chunk(data.vegetation[l])
		for chunk: Vector2i in chunks:
			root.add_child(_make_multimesh(layer, data.vegetation[l], chunks[chunk], chunk))
			if layer.collision_radius > 0.0:
				_add_collision(layer, data.vegetation[l], chunks[chunk])
				_register_cover(registry, layer, data.vegetation[l], chunks[chunk])


# Índices de instancia (en floats) agrupados por chunk.
func _group_by_chunk(instances: PackedFloat32Array) -> Dictionary[Vector2i, PackedInt32Array]:
	var chunks: Dictionary[Vector2i, PackedInt32Array] = {}
	for i: int in range(0, instances.size(), VegetationPhase.STRIDE):
		var key := Vector2i(floori(instances[i] / VEGETATION_CHUNK_M), floori(instances[i + 2] / VEGETATION_CHUNK_M))
		if not chunks.has(key):
			chunks[key] = PackedInt32Array()
		chunks[key].append(i)
	return chunks


func _make_multimesh(layer: VegetationLayer, instances: PackedFloat32Array,
		indices: PackedInt32Array, chunk: Vector2i) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = layer.mesh
	mm.instance_count = indices.size()
	# Las mallas primitivas tienen el origen en el centro: se suben para apoyarlas en el suelo.
	var base_offset: float = -layer.mesh.get_aabb().position.y
	for k: int in indices.size():
		var i: int = indices[k]
		var scale: float = instances[i + 4]
		var basis := Basis(Vector3.UP, instances[i + 3]).scaled(Vector3.ONE * scale)
		var origin := Vector3(instances[i], instances[i + 1] + base_offset * scale - VEGETATION_SINK_M, instances[i + 2])
		mm.set_instance_transform(k, Transform3D(basis, origin))
	var node := MultiMeshInstance3D.new()
	node.name = "%s_%d_%d" % [layer.id, chunk.x, chunk.y]
	node.multimesh = mm
	node.visibility_range_end = layer.visibility_range_m
	return node


# Un cuerpo estático por chunk con un cilindro por instancia, escalado como la instancia
# (escala uniforme) y sin nodos, directo al servidor de física.
func _add_collision(layer: VegetationLayer, instances: PackedFloat32Array, indices: PackedInt32Array) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = layer.collision_radius
	shape.height = layer.collision_height
	_collision_shapes.append(shape)
	var body: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body, get_world_3d().space)
	for i: int in indices:
		var scale: float = instances[i + 4]
		var origin := Vector3(instances[i], instances[i + 1] + layer.collision_height * 0.5 * scale, instances[i + 2])
		PhysicsServer3D.body_add_shape(body, shape.get_rid(), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), origin))
	_physics_bodies.append(body)


# Los obstáculos con colisión (troncos, rocas) sirven de cobertura a la IA.
func _register_cover(registry: CoverRegistry, layer: VegetationLayer, instances: PackedFloat32Array,
		indices: PackedInt32Array) -> void:
	for i: int in indices:
		var scale: float = instances[i + 4]
		registry.add_obstacle(Vector3(instances[i], instances[i + 1], instances[i + 2]),
				layer.collision_radius * scale, layer.collision_height * scale,
				CoverRegistry.Kind.ROCK if layer.is_rock else CoverRegistry.Kind.TREE, layer.resources)
