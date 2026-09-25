extends SceneTree
## Genera las mallas placeholder de árboles (tronco + copa) en data/vegetation/meshes/.
## Origen en la base del tronco. La colisión de la capa debe coincidir con el tronco.
## Uso: godot --headless --path . -s res://tools/build_vegetation_meshes.gd

const OUT_DIR: String = "res://data/vegetation/meshes"
const TRUNK_COLOR := Color(0.33, 0.24, 0.16)


func _init() -> void:
	var pine_canopy := CylinderMesh.new()
	pine_canopy.top_radius = 0.0
	pine_canopy.bottom_radius = 1.7
	pine_canopy.height = 7.0
	pine_canopy.radial_segments = 8
	pine_canopy.rings = 1
	_save("pine_mesh", _tree(0.3, 2.6, pine_canopy, 2.0 + 3.5, Color(0.12, 0.3, 0.16)))

	var broadleaf_canopy := SphereMesh.new()
	broadleaf_canopy.radius = 2.4
	broadleaf_canopy.height = 3.6
	broadleaf_canopy.radial_segments = 10
	broadleaf_canopy.rings = 5
	_save("broadleaf_mesh", _tree(0.35, 3.4, broadleaf_canopy, 4.6, Color(0.25, 0.42, 0.18)))
	quit()


# Tronco (cilindro desde y=0) + copa centrada en canopy_center_y, cada uno con su material.
func _tree(trunk_radius: float, trunk_height: float, canopy: PrimitiveMesh,
		canopy_center_y: float, canopy_color: Color) -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = trunk_radius * 0.8
	trunk.bottom_radius = trunk_radius
	trunk.height = trunk_height
	trunk.radial_segments = 8
	trunk.rings = 1
	var mesh := ArrayMesh.new()
	_add_surface(mesh, trunk, Vector3(0, trunk_height * 0.5, 0), TRUNK_COLOR)
	_add_surface(mesh, canopy, Vector3(0, canopy_center_y, 0), canopy_color)
	return mesh


func _add_surface(mesh: ArrayMesh, source: PrimitiveMesh, offset: Vector3, color: Color) -> void:
	var st := SurfaceTool.new()
	st.append_from(source, 0, Transform3D(Basis.IDENTITY, offset))
	st.commit(mesh)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func _save(file_name: String, mesh: ArrayMesh) -> void:
	var path: String = "%s/%s.tres" % [OUT_DIR, file_name]
	var err: Error = ResourceSaver.save(mesh, path)
	print("%s: %s (AABB %s)" % [path, error_string(err), mesh.get_aabb()])
