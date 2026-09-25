class_name BaseModel
extends RefCounted
## Una base: rejilla de construcción anclada al primer cimiento (GDD §10). Modelo puro:
## valida el encaje (los "sockets") y guarda las piezas como datos (tipo, material,
## posición en la rejilla, vida) para la persistencia (GDD §10, §13).
##
## Rejilla: celdas de CELL_M × CELL_M, niveles de LEVEL_M. Una celda (x, z, nivel)
## acoge un cimiento (nivel 0), un suelo/techo (nivel ≥ 1) o unas escaleras. Un borde
## (celda, lado, nivel) acoge una pared (o pared con puerta/ventana) y, en una pared con
## hueco, una puerta. Un vértice (x, z, nivel) acoge un pilar.
## 🔶 Sin integridad estructural (fuera de la v0.1): solo reglas de apoyo al colocar.

const CELL_M: float = 3.0
const LEVEL_M: float = 3.0
## Lados de una celda: 0 = -Z (norte), 1 = +X (este), 2 = +Z (sur), 3 = -X (oeste).
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

const K := BuildingPieceDefinition.Kind


class Piece:
	extends RefCounted
	var uid: int = 0
	var definition: BuildingPieceDefinition
	var material: BuildingMaterial
	var cell: Vector3i
	## Lado (0-3) para piezas de borde; -1 si no aplica.
	var side: int = -1
	var hp: float = 0.0

	func key() -> String:
		return BaseModel.slot_key(definition, cell, side)


var id: int = 0
## Posición y giro (solo Y) de la celda (0, 0, 0) en el mundo.
var origin: Transform3D
## Altura del suelo de la base (cara superior de los cimientos).
var floor_height: float = 0.0
var pieces: Dictionary[String, Piece] = {}

var _next_uid: int = 1


func _init(base_id: int, base_origin: Transform3D) -> void:
	id = base_id
	origin = base_origin
	floor_height = base_origin.origin.y


# --- Claves y posiciones ---

## Clave del hueco que ocupa una pieza. Las paredes se normalizan para que el borde
## compartido por dos celdas vecinas tenga una sola clave.
static func slot_key(def: BuildingPieceDefinition, cell: Vector3i, side: int) -> String:
	match def.slot():
		BuildingPieceDefinition.Slot.CELL:
			return "C:%d:%d:%d:%s" % [cell.x, cell.y, cell.z, "S" if def.kind == K.STAIRS else "F"]
		BuildingPieceDefinition.Slot.VERTEX:
			return "V:%d:%d:%d" % [cell.x, cell.y, cell.z]
	var edge: Array = _normal_edge(cell, side)
	var prefix: String = "D" if def.kind == K.DOOR else "E"
	return "%s:%d:%d:%d:%d" % [prefix, edge[0].x, edge[0].y, edge[0].z, edge[1]]


static func _normal_edge(cell: Vector3i, side: int) -> Array:
	# Los lados sur y este se expresan como el norte/oeste de la celda vecina.
	if side == 2:
		return [cell + Vector3i(0, 0, 1), 0]
	if side == 1:
		return [cell + Vector3i(1, 0, 0), 3]
	return [cell, side]


## Transform en el mundo de una pieza en su hueco.
func piece_transform(def: BuildingPieceDefinition, cell: Vector3i, side: int) -> Transform3D:
	var local := Vector3((cell.x + 0.5) * CELL_M, cell.y * LEVEL_M, (cell.z + 0.5) * CELL_M)
	var yaw: float = 0.0
	match def.slot():
		BuildingPieceDefinition.Slot.EDGE:
			var dir: Vector2i = SIDES[side]
			local += Vector3(dir.x, 0, dir.y) * CELL_M * 0.5
			yaw = -side * PI * 0.5
		BuildingPieceDefinition.Slot.VERTEX:
			local = Vector3(cell.x * CELL_M, cell.y * LEVEL_M, cell.z * CELL_M)
	var local_transform := Transform3D(Basis(Vector3.UP, yaw), local)
	return origin * local_transform


## Celda de la rejilla que contiene un punto del mundo (nivel según su altura).
func cell_at(world_point: Vector3) -> Vector3i:
	var local: Vector3 = origin.affine_inverse() * world_point
	return Vector3i(floori(local.x / CELL_M), maxi(roundi(local.y / LEVEL_M), 0), floori(local.z / CELL_M))


## Lado de la celda más cercano a un punto del mundo.
func nearest_side(cell: Vector3i, world_point: Vector3) -> int:
	var local: Vector3 = origin.affine_inverse() * world_point
	var offset := Vector2(local.x - (cell.x + 0.5) * CELL_M, local.z - (cell.z + 0.5) * CELL_M)
	if absf(offset.x) > absf(offset.y):
		return 1 if offset.x > 0.0 else 3
	return 2 if offset.y > 0.0 else 0


# --- Reglas de encaje (sockets) ---

func has(def_kind: K, cell: Vector3i, side: int = -1) -> bool:
	for piece: Piece in pieces.values():
		if piece.definition.kind == def_kind and piece.cell == cell and (side < 0 or piece.side == side):
			return true
	return false


func _has_floor_at(cell: Vector3i) -> bool:
	return pieces.has("C:%d:%d:%d:F" % [cell.x, cell.y, cell.z])


func _has_wall_at(cell: Vector3i, side: int) -> bool:
	var probe := BuildingPieceDefinition.new()
	probe.kind = K.WALL
	return pieces.has(slot_key(probe, cell, side))


func _wall_piece_at(cell: Vector3i, side: int) -> Piece:
	var probe := BuildingPieceDefinition.new()
	probe.kind = K.WALL
	return pieces.get(slot_key(probe, cell, side)) as Piece


## Motivo por el que no se puede colocar, o "" si se puede.
func placement_error(def: BuildingPieceDefinition, cell: Vector3i, side: int) -> String:
	if pieces.has(slot_key(def, cell, side)):
		return "ya hay algo ahí"
	match def.kind:
		K.FOUNDATION:
			if cell.y != 0:
				return "los cimientos van en el suelo"
			if not pieces.is_empty() and not _touches_foundation(cell):
				return "tiene que tocar otro cimiento"
		K.FLOOR:
			if cell.y < 1:
				return "los suelos van sobre paredes"
			if not _floor_supported(cell):
				return "necesita paredes o pilares debajo"
		K.WALL, K.DOORWAY, K.WINDOW_WALL:
			if side < 0:
				return "falta el lado"
			if not (_has_floor_at(cell) or _has_floor_at(cell + Vector3i(SIDES[side].x, 0, SIDES[side].y))):
				return "necesita un cimiento o suelo"
		K.DOOR:
			var wall: Piece = _wall_piece_at(cell, side)
			if wall == null or wall.definition.kind != K.DOORWAY:
				return "va en una pared con puerta"
		K.STAIRS:
			if not _has_floor_at(cell):
				return "necesita un cimiento o suelo"
		K.PILLAR:
			if not _vertex_supported(cell):
				return "necesita un cimiento o suelo al lado"
	return ""


func _touches_foundation(cell: Vector3i) -> bool:
	for dir: Vector2i in SIDES:
		if _has_floor_at(cell + Vector3i(dir.x, 0, dir.y)):
			return true
	return false


func _floor_supported(cell: Vector3i) -> bool:
	var below: Vector3i = cell - Vector3i(0, 1, 0)
	for side: int in 4:
		if _has_wall_at(below, side):
			return true
	for corner: Vector3i in [below, below + Vector3i(1, 0, 0), below + Vector3i(0, 0, 1), below + Vector3i(1, 0, 1)]:
		if pieces.has("V:%d:%d:%d" % [corner.x, corner.y, corner.z]):
			return true
	# Junto a otro suelo del mismo nivel (voladizo de una celda).
	return _touches_foundation(cell)


func _vertex_supported(vertex: Vector3i) -> bool:
	for offset: Vector3i in [Vector3i(0, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(-1, 0, -1)]:
		if _has_floor_at(vertex + offset):
			return true
	return false


# --- Cambios ---

func add(def: BuildingPieceDefinition, material: BuildingMaterial, cell: Vector3i, side: int) -> Piece:
	if placement_error(def, cell, side) != "":
		return null
	var piece := Piece.new()
	piece.uid = _next_uid
	_next_uid += 1
	piece.definition = def
	piece.material = material
	piece.cell = cell
	piece.side = side if def.slot() == BuildingPieceDefinition.Slot.EDGE else -1
	piece.hp = def.max_hp(material)
	pieces[piece.key()] = piece
	return piece


## Restaura una pieza guardada tal cual (sin validar el apoyo).
func restore(def: BuildingPieceDefinition, material: BuildingMaterial, cell: Vector3i, side: int, hp: float, uid: int) -> Piece:
	var piece := Piece.new()
	piece.uid = uid
	_next_uid = maxi(_next_uid, uid + 1)
	piece.definition = def
	piece.material = material
	piece.cell = cell
	piece.side = side
	piece.hp = hp
	pieces[piece.key()] = piece
	return piece


func remove(piece: Piece) -> void:
	pieces.erase(piece.key())


func find_uid(uid: int) -> Piece:
	for piece: Piece in pieces.values():
		if piece.uid == uid:
			return piece
	return null


## Mejora una pieza a un material de tier superior, conservando la proporción de vida.
func upgrade(piece: Piece, material: BuildingMaterial) -> bool:
	if material.tier <= piece.material.tier:
		return false
	var ratio: float = piece.hp / piece.definition.max_hp(piece.material)
	piece.material = material
	piece.hp = piece.definition.max_hp(material) * ratio
	return true
