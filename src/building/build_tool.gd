class_name BuildTool
extends Node
## Modo construcción del jugador (GDD §10): vista previa fantasma que encaja en la rejilla,
## verde si se puede colocar y roja si no; clic para colocar, U para mejorar la pieza a la
## que se apunta. La validación de verdad la hace el host (BuildingManager).
##
## Controles (con el modo activo, B): rueda = pieza, T = material, R = girar base nueva,
## clic izquierdo = colocar, U = mejorar al siguiente material.

signal changed()

@export var pieces: Array[BuildingPieceDefinition] = []
@export var materials: Array[BuildingMaterial] = []
@export var reach_m: float = 6.0

var active: bool = false
var piece_index: int = 0
var material_index: int = 0
## Motivo por el que la vista previa no es válida ("" si lo es).
var status: String = ""

var _yaw_offset: float = 0.0
var _ghost: BuildingPieceNode
var _ghost_kind: int = -1
var _target_point: Vector3
var _has_target: bool = false

@onready var _player: Player = get_parent() as Player


func manager() -> BuildingManager:
	return get_tree().get_first_node_in_group(&"building_manager") as BuildingManager


func current_piece() -> BuildingPieceDefinition:
	return pieces[piece_index]


func current_material() -> BuildingMaterial:
	return materials[material_index]


func set_active(value: bool) -> void:
	active = value and manager() != null
	if not active:
		_clear_ghost()
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		set_active(not active)
		return
	if not active:
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_piece(1)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_piece(-1)
	if event.is_action_pressed(&"build_material"):
		material_index = (material_index + 1) % materials.size()
		changed.emit()
	elif event.is_action_pressed(&"reload"):
		_yaw_offset += PI * 0.5
	elif event.is_action_pressed(&"build_upgrade"):
		upgrade_target()


func cycle_piece(step: int) -> void:
	piece_index = wrapi(piece_index + step, 0, pieces.size())
	_clear_ghost()
	changed.emit()


func _physics_process(_delta: float) -> void:
	if not active:
		return
	_update_target()
	_update_ghost()


func _update_target() -> void:
	var cam: Camera3D = _player.camera()
	var from: Vector3 = cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * reach_m,
			PhysicsLayers.WORLD, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	_has_target = not hit.is_empty()
	if _has_target:
		_target_point = hit.position as Vector3
		# Apuntando a una pieza: el hueco está al otro lado de la superficie tocada.
		if hit.collider is BuildingPieceNode:
			_target_point += (hit.normal as Vector3) * 0.2


func _yaw() -> float:
	return _player.rotation.y + _yaw_offset


func _update_ghost() -> void:
	var build := manager()
	if not _has_target or build == null:
		_clear_ghost()
		status = "apunta al suelo o a tu base"
		return
	var def: BuildingPieceDefinition = current_piece()
	var slot: Dictionary = build.resolve_slot(def, _target_point, _yaw())
	status = build.placement_error(def, slot)
	var cost: int = def.cost(current_material())
	if status == "" and BuildingManager.count_item(_player.inventory.inventory, current_material().resource_item) < cost:
		status = "faltan %d de %s" % [cost, current_material().resource_item.display_name.to_lower()]
	if slot.is_empty():
		_clear_ghost()
		return
	if _ghost == null or _ghost_kind != def.kind:
		_clear_ghost()
		var preview := BaseModel.Piece.new()
		preview.definition = def
		preview.material = current_material()
		preview.hp = def.max_hp(current_material())
		_ghost = BuildingPieceNode.new()
		_ghost.setup(preview, true)
		_ghost_kind = def.kind
		_player.get_parent().add_child(_ghost)
	_ghost.global_transform = slot.transform as Transform3D
	_ghost.refresh_material(status == "")


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = null
	_ghost_kind = -1


## Intenta colocar la pieza de la vista previa (la valida el host).
func place() -> void:
	if not active or not _has_target or manager() == null:
		return
	manager().request_place(_player, current_piece(), current_material(), _target_point, _yaw())


## Mejora al siguiente material la pieza a la que apunta.
func upgrade_target() -> void:
	var cam: Camera3D = _player.camera()
	var from: Vector3 = cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * reach_m,
			PhysicsLayers.WORLD, [_player.get_rid()])
	var node := _player.get_world_3d().direct_space_state.intersect_ray(query).get("collider") as BuildingPieceNode
	if node == null:
		return
	for material: BuildingMaterial in materials:
		if material.tier == node.piece.material.tier + 1:
			manager().request_upgrade(_player, node, material)
			return


func describe() -> String:
	if not active:
		return ""
	var def: BuildingPieceDefinition = current_piece()
	var material: BuildingMaterial = current_material()
	var have: int = BuildingManager.count_item(_player.inventory.inventory, material.resource_item)
	var line: String = "CONSTRUIR: %s de %s · coste %d %s (tienes %d)" % [def.display_name, material.display_name.to_lower(),
			def.cost(material), material.resource_item.display_name.to_lower(), have]
	return line + ("" if status == "" else "  —  " + status)
