class_name BuildingManager
extends Node3D
## Bases construidas en el mundo (GDD §10). El host valida y aplica toda colocación y
## mejora (AGENTS.md §1.1): distancia, coste en el inventario del jugador, encaje en la
## rejilla, altura del terreno (pilares hasta una altura máxima) y colisión.
## La persistencia guarda las bases como datos (tipo, material, posición, vida), no escenas.

signal base_changed(base_id: int)

## Distancia máxima del jugador a la pieza que coloca o mejora.
@export var max_reach_m: float = 8.0
## Cimientos: el terreno no puede quedar por encima de la cara superior más de esto.
@export var max_ground_above_m: float = 0.25

var bases: Array[BaseModel] = []
## "base_id:uid" -> nodo de la pieza.
var _nodes: Dictionary[String, BuildingPieceNode] = {}
var _next_base_id: int = 1


func _ready() -> void:
	add_to_group(&"building_manager")


# --- Consultas (las usa también la vista previa del cliente) ---

## Base y hueco para colocar `def` apuntando a `point`. Devuelve {"base", "cell", "side",
## "transform"}; si no hay base cercana y es un cimiento, "base" es null (base nueva).
func resolve_slot(def: BuildingPieceDefinition, point: Vector3, yaw: float) -> Dictionary:
	for base: BaseModel in bases:
		var cell: Vector3i = base.cell_at(point)
		if def.kind == BuildingPieceDefinition.Kind.FOUNDATION:
			cell.y = 0
		if not _near_base(base, cell):
			continue
		var side: int = base.nearest_side(cell, point) if def.slot() == BuildingPieceDefinition.Slot.EDGE else -1
		if def.slot() == BuildingPieceDefinition.Slot.VERTEX:
			cell = _nearest_vertex(base, point)
		return {"base": base, "cell": cell, "side": side, "transform": base.piece_transform(def, cell, side)}
	if def.kind != BuildingPieceDefinition.Kind.FOUNDATION:
		return {}
	# Base nueva: la celda (0, 0) centrada en el punto, con el giro del jugador en pasos de 90°.
	var snapped_yaw: float = roundf(yaw / (PI * 0.5)) * PI * 0.5
	var basis := Basis(Vector3.UP, snapped_yaw)
	var origin_point: Vector3 = point + Vector3.UP * BuildingPieceNode.FOUNDATION_T - basis * Vector3(BaseModel.CELL_M * 0.5, 0, BaseModel.CELL_M * 0.5)
	var preview := BaseModel.new(0, Transform3D(basis, origin_point))
	return {"base": null, "cell": Vector3i.ZERO, "side": -1, "origin": preview.origin,
			"transform": preview.piece_transform(def, Vector3i.ZERO, -1)}


func _near_base(base: BaseModel, cell: Vector3i) -> bool:
	for piece: BaseModel.Piece in base.pieces.values():
		if absi(piece.cell.x - cell.x) <= 1 and absi(piece.cell.z - cell.z) <= 1 and absi(piece.cell.y - cell.y) <= 1:
			return true
	return false


func _nearest_vertex(base: BaseModel, point: Vector3) -> Vector3i:
	var local: Vector3 = base.origin.affine_inverse() * point
	return Vector3i(roundi(local.x / BaseModel.CELL_M), maxi(roundi(local.y / BaseModel.LEVEL_M), 0), roundi(local.z / BaseModel.CELL_M))


## Motivo por el que no se puede colocar (vacío si se puede), sin mirar el coste.
func placement_error(def: BuildingPieceDefinition, slot: Dictionary) -> String:
	if slot.is_empty():
		return "no hay dónde apoyarla"
	var base: BaseModel = slot.base
	if base != null:
		var error: String = base.placement_error(def, slot.cell, slot.side)
		if error != "":
			return error
	if def.kind == BuildingPieceDefinition.Kind.FOUNDATION:
		var error: String = _terrain_error(slot.transform)
		if error != "":
			return error
	if _blocked(def, slot.transform):
		return "hay algo en medio"
	return ""


func _terrain_error(foundation: Transform3D) -> String:
	var heights: PackedFloat32Array = ground_heights(foundation)
	for h: float in heights:
		if is_nan(h):
			return "no hay suelo debajo"
		if h > foundation.origin.y + max_ground_above_m:
			return "el terreno está demasiado alto"
		if foundation.origin.y - BuildingPieceNode.FOUNDATION_T - h > BuildingPieceNode.MAX_PILLAR_M:
			return "demasiado alto (pilares de más de %.0f m)" % BuildingPieceNode.MAX_PILLAR_M
	return ""


## Altura del suelo bajo las 4 esquinas de un cimiento (NAN si no hay suelo).
func ground_heights(foundation: Transform3D) -> PackedFloat32Array:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var half: float = BaseModel.CELL_M * 0.5 - 0.2
	var result := PackedFloat32Array()
	for corner: Vector3 in [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]:
		var top: Vector3 = foundation * corner + Vector3.UP * 5.0
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 20.0, PhysicsLayers.WORLD, _piece_rids())
		var hit: Dictionary = space.intersect_ray(query)
		result.append((hit.position as Vector3).y if not hit.is_empty() else NAN)
	return result


# Colisión con el mundo (salvo las piezas de base, que se tocan entre sí) y personajes.
func _blocked(def: BuildingPieceDefinition, at: Transform3D) -> bool:
	if _volume(def) == Vector3.ZERO:
		return false
	# Algo más pequeño que la pieza: las piezas vecinas se tocan sin solaparse.
	var size: Vector3 = (_volume(def) - Vector3.ONE * 0.3).max(Vector3.ONE * 0.1)
	var box := BoxShape3D.new()
	box.size = size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = at * Transform3D(Basis.IDENTITY, Vector3(0, _volume(def).y * 0.5, 0))
	params.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CHARACTERS
	params.exclude = _piece_rids()
	# El terreno no cuenta como obstáculo para la parte por encima del suelo.
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(params, 8):
		var collider: Object = hit.get("collider")
		# Sin nodo = colisión de servidor de la vegetación (un tronco o una roca en medio).
		if collider == null or not collider is Terrain3D:
			return true
	return false


static func _volume(def: BuildingPieceDefinition) -> Vector3:
	var c: float = BaseModel.CELL_M
	match def.kind:
		BuildingPieceDefinition.Kind.FOUNDATION:
			return Vector3(c, 2.0, c)
		BuildingPieceDefinition.Kind.FLOOR:
			return Vector3(c, 0.2, c)
		BuildingPieceDefinition.Kind.PILLAR:
			return Vector3(0.35, BaseModel.LEVEL_M, 0.35)
		BuildingPieceDefinition.Kind.DOOR:
			return Vector3.ZERO
		BuildingPieceDefinition.Kind.STAIRS:
			return Vector3(1.4, 1.0, 1.0)
	return Vector3(c, BaseModel.LEVEL_M, 0.2)


func _piece_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for node: BuildingPieceNode in _nodes.values():
		if is_instance_valid(node):
			rids.append(node.get_rid())
	return rids


# --- Solicitudes (jugador -> host) ---

func request_place(player: Player, def: BuildingPieceDefinition, material: BuildingMaterial, point: Vector3, yaw: float) -> void:
	_server_place.rpc_id(1, player.get_path(), def.resource_path, material.resource_path, point, yaw)


func request_upgrade(player: Player, piece_node: BuildingPieceNode, material: BuildingMaterial) -> void:
	_server_upgrade.rpc_id(1, player.get_path(), piece_node.get_path(), material.resource_path)


@rpc("any_peer", "call_local", "reliable")
func _server_place(player_path: NodePath, def_path: String, material_path: String, point: Vector3, yaw: float) -> void:
	var player := _validated_player(player_path, point)
	if player == null:
		return
	var def := load(def_path) as BuildingPieceDefinition
	var material := load(material_path) as BuildingMaterial
	if def == null or material == null:
		return
	var slot: Dictionary = resolve_slot(def, point, yaw)
	if placement_error(def, slot) != "" or not _pay(player, material, def.cost(material)):
		return
	var base: BaseModel = slot.base
	if base == null:
		base = BaseModel.new(_next_base_id, slot.origin as Transform3D)
		_next_base_id += 1
		bases.append(base)
	var piece: BaseModel.Piece = base.add(def, material, slot.cell, slot.side)
	if piece != null:
		spawn_piece_node(base, piece)
		EventBus.sound_emitted.emit(point, 30.0, &"construction", player)
		base_changed.emit(base.id)


@rpc("any_peer", "call_local", "reliable")
func _server_upgrade(player_path: NodePath, piece_path: NodePath, material_path: String) -> void:
	var node := get_node_or_null(piece_path) as BuildingPieceNode
	if node == null:
		return
	var player := _validated_player(player_path, node.global_position)
	var material := load(material_path) as BuildingMaterial
	if player == null or material == null or material.tier <= node.piece.material.tier:
		return
	if not _pay(player, material, node.piece.definition.cost(material)):
		return
	var base: BaseModel = find_base(node.base_id)
	if base.upgrade(node.piece, material):
		node.refresh_material()
		base_changed.emit(base.id)


func _validated_player(player_path: NodePath, point: Vector3) -> Player:
	if not multiplayer.is_server():
		return null
	var player := get_node_or_null(player_path) as Player
	if player == null or player.health.is_dead:
		return null
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != player.inventory.owner_peer_id and sender != 0:
		return null
	if player.global_position.distance_to(point) > max_reach_m:
		return null
	return player


func _pay(player: Player, material: BuildingMaterial, amount: int) -> bool:
	var inv: Inventory = player.inventory.inventory
	if count_item(inv, material.resource_item) < amount:
		return false
	take_item(inv, material.resource_item, amount)
	player.inventory.inventory_changed.emit()
	return true


static func count_item(inv: Inventory, def: ItemDefinition) -> int:
	var total: int = 0
	for container: ItemContainer in inv.storage():
		for item: ItemInstance in _all_items(container):
			if item.definition == def:
				total += item.quantity
	return total


static func take_item(inv: Inventory, def: ItemDefinition, amount: int) -> void:
	for container: ItemContainer in inv.storage():
		for item: ItemInstance in _all_items(container):
			if amount <= 0:
				return
			if item.definition == def:
				var used: int = mini(item.quantity, amount)
				item.quantity -= used
				amount -= used
				if item.quantity <= 0:
					item.location().remove(item)


static func _all_items(container: ItemContainer) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in container.items():
		result.append(item)
		if item.contents != null:
			result.append_array(_all_items(item.contents))
	return result


# --- Nodos ---

func find_base(base_id: int) -> BaseModel:
	for base: BaseModel in bases:
		if base.id == base_id:
			return base
	return null


func spawn_piece_node(base: BaseModel, piece: BaseModel.Piece) -> BuildingPieceNode:
	var node := BuildingPieceNode.new()
	node.name = "Base%d_Piece%d" % [base.id, piece.uid]
	node.manager = self
	node.base_id = base.id
	node.setup(piece)
	add_child(node)
	node.global_transform = base.piece_transform(piece.definition, piece.cell, piece.side)
	_nodes["%d:%d" % [base.id, piece.uid]] = node
	if piece.definition.kind == BuildingPieceDefinition.Kind.FOUNDATION:
		node.add_support_pillars(ground_heights(node.global_transform))
	return node


func piece_node(base_id: int, uid: int) -> BuildingPieceNode:
	return _nodes.get("%d:%d" % [base_id, uid]) as BuildingPieceNode


func remove_piece(base_id: int, piece: BaseModel.Piece) -> void:
	var base: BaseModel = find_base(base_id)
	if base == null:
		return
	base.remove(piece)
	_nodes.erase("%d:%d" % [base_id, piece.uid])
	if base.pieces.is_empty():
		bases.erase(base)
	base_changed.emit(base_id)


## Reconstruye una base guardada (M6: persistencia).
func restore_base(base: BaseModel) -> void:
	bases.append(base)
	_next_base_id = maxi(_next_base_id, base.id + 1)
	for piece: BaseModel.Piece in base.pieces.values():
		spawn_piece_node(base, piece)
