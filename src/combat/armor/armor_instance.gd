class_name ArmorInstance
extends RefCounted
## Una pieza de armadura equipada, con su durabilidad actual.
## En M3 pasará a ser el estado de un ItemInstance del inventario.

var definition: ArmorDefinition
var durability: float = 0.0


func _init(def: ArmorDefinition, current_durability: float = -1.0) -> void:
	definition = def
	durability = def.max_durability if current_durability < 0.0 else current_durability


func durability_ratio() -> float:
	return durability / definition.max_durability if definition.max_durability > 0.0 else 0.0


func protects(zone: BodyZones.Zone) -> bool:
	return definition.protected_zones.has(zone)
