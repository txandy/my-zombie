class_name NavRegionBuilder
## Hornea en tiempo de ejecución una malla de navegación para una zona del mundo generado
## (GDD §11.2, §16: NavigationServer3D). Fuentes: el terreno de Terrain3D, la geometría
## de los nodos de `geometry_root` (POIs) y los troncos/rocas como obstáculos proyectados.
## El horneado es asíncrono; la región aparece en el mapa de navegación al terminar.

## Múltiplos del tamaño de celda del mapa de navegación (0.25 m), para no perder precisión.
const AGENT_RADIUS_M: float = 0.5
const AGENT_HEIGHT_M: float = 1.75


static func bake(parent: Node3D, center: Vector3, half_size_m: float, terrain: Terrain3D,
		geometry_root: Node, cover: CoverRegistry) -> NavigationRegion3D:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = AGENT_RADIUS_M
	nav_mesh.agent_height = AGENT_HEIGHT_M
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 40.0
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var bounds := AABB(center - Vector3(half_size_m, 60.0, half_size_m), Vector3(half_size_m * 2.0, 160.0, half_size_m * 2.0))
	nav_mesh.filter_baking_aabb = bounds
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	parent.add_child(region)
	# Los CSG generan su geometría y colisión en el frame siguiente: se parsea después.
	# Se guarda el árbol: si la escena se libera mientras espera, el trabajo se cancela.
	var tree: SceneTree = parent.get_tree()
	var job := func() -> void:
		await tree.process_frame
		await tree.physics_frame
		if not is_instance_valid(region) or not region.is_inside_tree():
			return
		var source := NavigationMeshSourceGeometryData3D.new()
		if geometry_root != null and is_instance_valid(geometry_root):
			NavigationServer3D.parse_source_geometry_data(nav_mesh, source, geometry_root)
		if terrain != null:
			source.add_faces(terrain.generate_nav_mesh_source_geometry(bounds, false), Transform3D.IDENTITY)
		if cover != null:
			_add_obstacles(source, cover, center, half_size_m)
		NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh, source,
				func() -> void:
					if is_instance_valid(region):
						region.navigation_mesh = nav_mesh)
	job.call()
	return region


# Troncos y rocas: su colisión es de servidor (sin nodos), así que se añaden a mano.
static func _add_obstacles(source: NavigationMeshSourceGeometryData3D, cover: CoverRegistry,
		center: Vector3, half_size_m: float) -> void:
	for obstacle: Dictionary in cover.obstacles_near(center, half_size_m * 1.42):
		var p: Vector3 = obstacle.position
		var r: float = float(obstacle.radius)
		var outline := PackedVector3Array([p + Vector3(-r, 0, -r), p + Vector3(r, 0, -r),
				p + Vector3(r, 0, r), p + Vector3(-r, 0, r)])
		source.add_projected_obstruction(outline, p.y - 2.0, float(obstacle.height) + 4.0, false)
