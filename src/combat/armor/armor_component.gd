class_name ArmorComponent
extends Node
## Armadura equipada de un personaje. En M3 se alimentará de los slots de equipo del inventario.

@export var starting_armor: Array[ArmorDefinition] = []

var pieces: Array[ArmorInstance] = []


func _ready() -> void:
	reset()


func reset() -> void:
	pieces.clear()
	for def: ArmorDefinition in starting_armor:
		pieces.append(ArmorInstance.new(def))


## Pieza que protege la zona, o null.
func piece_for(zone: BodyZones.Zone) -> ArmorInstance:
	for piece: ArmorInstance in pieces:
		if piece.protects(zone):
			return piece
	return null
