class_name ImpactMarkers
extends Node3D
## Marcas de impacto de depuración: una esfera pequeña donde acaba cada bala
## (gris en el mundo, roja en una hitbox) que desaparece tras unos segundos. Solo presentación.

@export var lifetime_s: float = 6.0
@export var max_markers: int = 200

var _world_mesh: SphereMesh
var _hit_mesh: SphereMesh


func _ready() -> void:
	_world_mesh = _make_mesh(Color(0.1, 0.1, 0.1))
	_hit_mesh = _make_mesh(Color(0.9, 0.15, 0.1))
	Ballistics.projectile_impacted.connect(_on_impact)


func _make_mesh(color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	return mesh


func _on_impact(position: Vector3, _normal: Vector3, hitbox: Hitbox, _source: Node) -> void:
	var marker := MeshInstance3D.new()
	marker.mesh = _hit_mesh if hitbox != null else _world_mesh
	add_child(marker)
	marker.global_position = position
	if get_child_count() > max_markers:
		get_child(0).queue_free()
	get_tree().create_timer(lifetime_s).timeout.connect(marker.queue_free)
