class_name ArmorInstance
extends RefCounted
## Una pieza de armadura equipada, con su durabilidad actual.
## Si viene de un objeto del inventario, la durabilidad se guarda en ese ItemInstance
## (así el desgaste persiste al quitársela, soltarla o guardarla).

var definition: ArmorDefinition
## Objeto del inventario del que sale, o null (armadura fija de un dummy).
var item: ItemInstance

var durability: float:
	get:
		return item.durability if item != null else _durability
	set(value):
		_durability = value
		if item != null:
			item.durability = value

var _durability: float = 0.0


func _init(def: ArmorDefinition, current_durability: float = -1.0, source: ItemInstance = null) -> void:
	definition = def
	item = source
	if source == null:
		_durability = def.max_durability if current_durability < 0.0 else current_durability


static func from_item(source: ItemInstance) -> ArmorInstance:
	return ArmorInstance.new(source.definition.armor, -1.0, source)


func durability_ratio() -> float:
	return durability / definition.max_durability if definition.max_durability > 0.0 else 0.0


func protects(zone: BodyZones.Zone) -> bool:
	return definition.protected_zones.has(zone)
