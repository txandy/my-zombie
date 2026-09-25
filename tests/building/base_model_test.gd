# Tests del modelo de base: reglas de encaje (sockets), claves compartidas de paredes,
# posiciones en el mundo, mejora de material y restauración.
extends GdUnitTestSuite

var _foundation: BuildingPieceDefinition
var _floor: BuildingPieceDefinition
var _wall: BuildingPieceDefinition
var _doorway: BuildingPieceDefinition
var _door: BuildingPieceDefinition
var _stairs: BuildingPieceDefinition
var _pillar: BuildingPieceDefinition
var _wood: BuildingMaterial
var _stone: BuildingMaterial
var _base: BaseModel


func before() -> void:
	_foundation = load("res://data/building/pieces/foundation.tres") as BuildingPieceDefinition
	_floor = load("res://data/building/pieces/floor.tres") as BuildingPieceDefinition
	_wall = load("res://data/building/pieces/wall.tres") as BuildingPieceDefinition
	_doorway = load("res://data/building/pieces/doorway.tres") as BuildingPieceDefinition
	_door = load("res://data/building/pieces/door.tres") as BuildingPieceDefinition
	_stairs = load("res://data/building/pieces/stairs.tres") as BuildingPieceDefinition
	_pillar = load("res://data/building/pieces/pillar.tres") as BuildingPieceDefinition
	_wood = load("res://data/building/materials/wood.tres") as BuildingMaterial
	_stone = load("res://data/building/materials/stone.tres") as BuildingMaterial


func before_test() -> void:
	_base = BaseModel.new(1, Transform3D(Basis.IDENTITY, Vector3(100, 10, 50)))


func test_first_foundation_anywhere_then_must_touch() -> void:
	assert_object(_base.add(_foundation, _wood, Vector3i(0, 0, 0), -1)).is_not_null()
	assert_str(_base.placement_error(_foundation, Vector3i(5, 0, 5), -1)).is_not_empty()
	assert_object(_base.add(_foundation, _wood, Vector3i(1, 0, 0), -1)).is_not_null()
	assert_str(_base.placement_error(_foundation, Vector3i(1, 0, 0), -1)).is_equal("ya hay algo ahí")


func test_walls_need_a_floor_and_share_edges() -> void:
	assert_str(_base.placement_error(_wall, Vector3i(0, 0, 0), 0)).is_not_empty()
	_base.add(_foundation, _wood, Vector3i(0, 0, 0), -1)
	_base.add(_foundation, _wood, Vector3i(1, 0, 0), -1)
	assert_object(_base.add(_wall, _wood, Vector3i(0, 0, 0), 1)).is_not_null()
	# El lado oeste de la celda vecina es el mismo borde.
	assert_str(_base.placement_error(_wall, Vector3i(1, 0, 0), 3)).is_equal("ya hay algo ahí")


func test_floor_needs_support_below() -> void:
	_base.add(_foundation, _wood, Vector3i(0, 0, 0), -1)
	assert_str(_base.placement_error(_floor, Vector3i(0, 1, 0), -1)).is_not_empty()
	_base.add(_wall, _wood, Vector3i(0, 0, 0), 0)
	assert_object(_base.add(_floor, _wood, Vector3i(0, 1, 0), -1)).is_not_null()
	# Voladizo de una celda junto a un suelo existente.
	assert_object(_base.add(_floor, _wood, Vector3i(1, 1, 0), -1)).is_not_null()


func test_door_only_in_doorway() -> void:
	_base.add(_foundation, _wood, Vector3i(0, 0, 0), -1)
	_base.add(_wall, _wood, Vector3i(0, 0, 0), 0)
	assert_str(_base.placement_error(_door, Vector3i(0, 0, 0), 0)).is_not_empty()
	_base.add(_doorway, _wood, Vector3i(0, 0, 0), 2)
	assert_object(_base.add(_door, _wood, Vector3i(0, 0, 0), 2)).is_not_null()


func test_stairs_and_pillars_need_floor() -> void:
	assert_str(_base.placement_error(_stairs, Vector3i(0, 0, 0), -1)).is_not_empty()
	assert_str(_base.placement_error(_pillar, Vector3i(0, 0, 0), -1)).is_not_empty()
	_base.add(_foundation, _wood, Vector3i(0, 0, 0), -1)
	assert_object(_base.add(_stairs, _wood, Vector3i(0, 0, 0), -1)).is_not_null()
	assert_object(_base.add(_pillar, _wood, Vector3i(1, 0, 1), -1)).is_not_null()


func test_piece_world_transform_follows_base_origin() -> void:
	var base := BaseModel.new(2, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(10, 5, 10)))
	var t: Transform3D = base.piece_transform(_foundation, Vector3i(0, 0, 0), -1)
	var local_center := Vector3(1.5, 0, 1.5)
	assert_vector(t.origin).is_equal_approx(base.origin * local_center, Vector3.ONE * 0.001)
	var wall_t: Transform3D = base.piece_transform(_wall, Vector3i(0, 1, 0), 0)
	assert_float(wall_t.origin.y).is_equal_approx(5.0 + BaseModel.LEVEL_M, 0.001)


func test_cell_and_side_from_world_point() -> void:
	var cell: Vector3i = _base.cell_at(Vector3(100 + 4.5, 10, 50 + 1.0))
	assert_vector(Vector3(cell)).is_equal(Vector3(1, 0, 0))
	assert_int(_base.nearest_side(Vector3i(0, 0, 0), Vector3(100 + 1.5, 10, 50 + 0.1))).is_equal(0)
	assert_int(_base.nearest_side(Vector3i(0, 0, 0), Vector3(100 + 2.9, 10, 50 + 1.5))).is_equal(1)


func test_hp_and_cost_scale_with_material_and_kind() -> void:
	assert_float(_wall.max_hp(_stone)).is_greater(_wall.max_hp(_wood))
	assert_int(_foundation.cost(_wood)).is_greater(_wall.cost(_wood))


func test_upgrade_keeps_damage_ratio_and_only_goes_up() -> void:
	_base.add(_foundation, _wood, Vector3i(0, 0, 0), -1)
	var wall: BaseModel.Piece = _base.add(_wall, _wood, Vector3i(0, 0, 0), 0)
	wall.hp = _wall.max_hp(_wood) * 0.5
	assert_bool(_base.upgrade(wall, _stone)).is_true()
	assert_float(wall.hp).is_equal_approx(_wall.max_hp(_stone) * 0.5, 0.001)
	assert_bool(_base.upgrade(wall, _wood)).is_false()


func test_restore_keeps_uid_and_hp() -> void:
	var piece: BaseModel.Piece = _base.restore(_foundation, _stone, Vector3i(0, 0, 0), -1, 123.0, 42)
	assert_int(piece.uid).is_equal(42)
	assert_object(_base.find_uid(42)).is_same(piece)
	var next: BaseModel.Piece = _base.add(_foundation, _wood, Vector3i(1, 0, 0), -1)
	assert_int(next.uid).is_greater(42)
