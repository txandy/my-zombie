class_name LootEntry
extends Resource
## Una posible aparición en una tabla de loot (GDD §8).

@export var item: ItemDefinition
## Peso relativo frente a las demás entradas válidas.
@export var weight: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
## Tier mínimo del POI para que pueda aparecer.
@export_range(1, 4) var min_tier: int = 1
## Ids de bioma donde puede aparecer. Vacío = en todos.
@export var biomes: Array[StringName] = []


func is_valid_for(tier: int, biome_id: StringName) -> bool:
	return tier >= min_tier and (biomes.is_empty() or biomes.has(biome_id))
