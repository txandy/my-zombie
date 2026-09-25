class_name BuildingPieceDefinition
extends Resource
## Tipo de pieza de construcción (GDD §10). Valores en /data/building/pieces/*.tres.
## Las piezas encajan en una rejilla por base (celdas de 3 m, niveles de 3 m):
## cimientos y suelos ocupan celdas, paredes ocupan bordes de celda y pilares vértices.

enum Kind { FOUNDATION, FLOOR, WALL, DOORWAY, WINDOW_WALL, DOOR, STAIRS, PILLAR }
## Dónde encaja: celda (cimiento, suelo, escaleras), borde (paredes, puerta), vértice (pilar).
enum Slot { CELL, EDGE, VERTEX }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.WALL
## Multiplicadores sobre la vida y el coste de referencia del material.
@export var hp_multiplier: float = 1.0
@export var cost_multiplier: float = 1.0


func slot() -> Slot:
	match kind:
		Kind.FOUNDATION, Kind.FLOOR, Kind.STAIRS:
			return Slot.CELL
		Kind.PILLAR:
			return Slot.VERTEX
	return Slot.EDGE


func max_hp(material: BuildingMaterial) -> float:
	return material.base_hp * hp_multiplier


func cost(material: BuildingMaterial) -> int:
	return ceili(material.base_cost * cost_multiplier)
