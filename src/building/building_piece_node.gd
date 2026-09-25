class_name BuildingPieceNode
extends StaticBody3D
## Pieza de construcción en el mundo: geometría y colisión según su tipo, color según su
## material. Recibe daño estructural (zombis, balas) y las puertas se abren con F.
## La geometría es provisional (cajas) hasta tener arte (GDD §15).

signal destroyed()

const K := BuildingPieceDefinition.Kind
const WALL_T: float = 0.2
const FOUNDATION_T: float = 0.6
## Altura máxima de los pilares bajo un cimiento (GDD §10: hasta una altura máxima).
const MAX_PILLAR_M: float = 3.0

var manager: BuildingManager
var base_id: int = 0
var piece: BaseModel.Piece
var door_open: bool = false

var _ghost: bool = false
var _material: StandardMaterial3D
var _door_hinge: Node3D


## Construye la geometría. `ghost`: vista previa sin colisión y semitransparente.
func setup(source: BaseModel.Piece, ghost: bool = false) -> void:
	piece = source
	_ghost = ghost
	_material = StandardMaterial3D.new()
	if ghost:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		collision_layer = 0
	else:
		collision_layer = PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLES
		add_to_group(&"building_piece")
	collision_mask = 0
	refresh_material()
	_build_shape()


func refresh_material(valid: bool = true) -> void:
	if _ghost:
		_material.albedo_color = Color(0.3, 0.9, 0.4, 0.4) if valid else Color(0.95, 0.3, 0.25, 0.4)
	else:
		var damage: float = 1.0 - piece.hp / piece.definition.max_hp(piece.material)
		_material.albedo_color = piece.material.color.darkened(damage * 0.5)


func _build_shape() -> void:
	var c: float = BaseModel.CELL_M
	var h: float = BaseModel.LEVEL_M
	match piece.definition.kind:
		K.FOUNDATION:
			_box(Vector3(c, FOUNDATION_T, c), Vector3(0, -FOUNDATION_T * 0.5, 0))
		K.FLOOR:
			_box(Vector3(c, WALL_T, c), Vector3(0, -WALL_T * 0.5, 0))
		K.WALL:
			_box(Vector3(c, h, WALL_T), Vector3(0, h * 0.5, 0))
		K.DOORWAY:
			_box(Vector3(0.95, h, WALL_T), Vector3(-c * 0.5 + 0.475, h * 0.5, 0))
			_box(Vector3(0.95, h, WALL_T), Vector3(c * 0.5 - 0.475, h * 0.5, 0))
			_box(Vector3(1.1, h - 2.2, WALL_T), Vector3(0, 2.2 + (h - 2.2) * 0.5, 0))
		K.WINDOW_WALL:
			_box(Vector3(c, 1.0, WALL_T), Vector3(0, 0.5, 0))
			_box(Vector3(c, h - 2.0, WALL_T), Vector3(0, 2.0 + (h - 2.0) * 0.5, 0))
			_box(Vector3(1.0, 1.0, WALL_T), Vector3(-1.0, 1.5, 0))
			_box(Vector3(1.0, 1.0, WALL_T), Vector3(1.0, 1.5, 0))
		K.DOOR:
			_door_hinge = Node3D.new()
			_door_hinge.position = Vector3(-0.55, 0, 0)
			add_child(_door_hinge)
			_box(Vector3(1.1, 2.2, 0.08), Vector3(0.55, 1.1, 0), _door_hinge)
		K.STAIRS:
			# Rampa dentro de la celda que sube un nivel hacia -Z.
			var length: float = sqrt(c * c + h * h)
			_box(Vector3(1.4, 0.25, length), Vector3(0, h * 0.5, 0), null, Basis(Vector3.RIGHT, atan2(h, c)))
		K.PILLAR:
			_box(Vector3(0.35, h, 0.35), Vector3(0, h * 0.5, 0))


## Añade una caja visual (y su colisión si no es fantasma) como hijo de `parent`.
func _box(size: Vector3, center: Vector3, parent: Node3D = null, rotation_basis: Basis = Basis.IDENTITY) -> void:
	var local := Transform3D(rotation_basis, center)
	var holder := Node3D.new()
	holder.transform = local
	(parent if parent != null else self).add_child(holder)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	mesh_node.material_override = _material
	holder.add_child(mesh_node)
	if _ghost:
		return
	var shape := BoxShape3D.new()
	shape.size = size
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	# La colisión es hija directa del cuerpo, con la transformación acumulada.
	shape_node.transform = parent.transform * local if parent != null else local
	add_child(shape_node)


## Pilares visuales del cimiento hasta el suelo. `ground_heights`: altura del terreno
## bajo cada esquina (NAN si no hay suelo).
func add_support_pillars(ground_heights: PackedFloat32Array) -> void:
	var half: float = BaseModel.CELL_M * 0.5 - 0.2
	var corners: Array[Vector3] = [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	for i: int in corners.size():
		var ground: float = ground_heights[i]
		var drop: float = global_position.y - FOUNDATION_T - ground
		if is_nan(ground) or drop <= 0.05:
			continue
		_box(Vector3(0.35, drop, 0.35), corners[i] + Vector3(0, -FOUNDATION_T - drop * 0.5, 0))


# --- Daño y puertas ---

## Daño estructural (zombis, balas). Solo el host.
func receive_structure_damage(amount: float) -> void:
	if not multiplayer.is_server() or _ghost or amount <= 0.0:
		return
	piece.hp -= amount
	refresh_material()
	if manager != null and piece.hp > 0.0:
		manager.broadcast_piece_state(base_id, piece)
	if piece.hp <= 0.0:
		destroyed.emit()
		if manager != null:
			manager.remove_piece(base_id, piece)
		queue_free()


func interaction_text() -> String:
	if piece == null or _ghost or piece.definition.kind != K.DOOR:
		return ""
	return "Cerrar puerta" if door_open else "Abrir puerta"


## Host: abre o cierra la puerta.
func interact(_player: Player) -> void:
	if piece.definition.kind != K.DOOR:
		return
	set_door_open(not door_open)
	if manager != null:
		manager.broadcast_door(base_id, piece.uid, door_open)
	EventBus.sound_emitted.emit(global_position, 15.0, &"door", self)


func set_door_open(open: bool) -> void:
	door_open = open
	_door_hinge.rotation.y = -PI * 0.5 if door_open else 0.0
	for child: Node in get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			shape.disabled = door_open
