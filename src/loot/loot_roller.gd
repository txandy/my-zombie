class_name LootRoller
## Genera el contenido de un contenedor a partir de su tabla (GDD §8). Función pura:
## la aleatoriedad sale del RNG que se le pasa (en el juego, uno derivado de la seed
## del mundo y del id del contenedor: misma seed, mismo loot).


static func roll(table: LootTable, tier: int, biome_id: StringName, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	# Tiradas siempre en el mismo orden para que el resultado sea reproducible.
	var empty_roll: float = rng.randf()
	var rolls: int = rng.randi_range(table.min_rolls, table.max_rolls) + table.extra_rolls_per_tier * (tier - 1)
	if empty_roll < table.empty_chance:
		return result
	var valid: Array[LootEntry] = []
	var total_weight: float = 0.0
	for entry: LootEntry in table.entries:
		if entry.is_valid_for(tier, biome_id) and entry.weight > 0.0:
			valid.append(entry)
			total_weight += entry.weight
	if valid.is_empty():
		return result
	for i: int in rolls:
		var entry: LootEntry = _pick(valid, total_weight, rng.randf() * total_weight)
		var quantity: int = rng.randi_range(entry.min_quantity, maxi(entry.min_quantity, entry.max_quantity))
		result.append(ItemInstance.new(entry.item, quantity))
	return result


static func _pick(valid: Array[LootEntry], total_weight: float, target: float) -> LootEntry:
	var accumulated: float = 0.0
	for entry: LootEntry in valid:
		accumulated += entry.weight
		if target < accumulated:
			return entry
	return valid[valid.size() - 1]
