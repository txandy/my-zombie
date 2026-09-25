class_name LootTable
extends Resource
## Tabla de loot por tipo de contenedor (nevera, taquilla, caja militar...). GDD §8.
## El tier del POI añade tiradas y desbloquea entradas; el bioma filtra entradas.
## 🔶 Probabilidades y cantidades: placeholders de tuning.

@export var id: StringName = &""
@export var entries: Array[LootEntry] = []
## Tiradas con tier 1 (rango inclusivo).
@export var min_rolls: int = 0
@export var max_rolls: int = 0
## Tiradas extra por cada tier por encima de 1.
@export var extra_rolls_per_tier: int = 0
## Probabilidad de que el contenedor esté vacío.
@export_range(0.0, 1.0) var empty_chance: float = 0.0
