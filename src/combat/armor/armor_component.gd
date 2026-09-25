class_name ArmorComponent
extends Node
## Armadura equipada de un personaje: fija (starting_armor, dummies) o los objetos de
## armadura equipados en el inventario (set_from_items).

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


## Usa como armadura los objetos equipados que la tengan (casco, chaleco).
func set_from_items(items: Array[ItemInstance]) -> void:
	pieces.clear()
	for item: ItemInstance in items:
		if item != null and item.definition.armor != null:
			pieces.append(ArmorInstance.from_item(item))
