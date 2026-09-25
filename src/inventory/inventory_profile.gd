class_name InventoryProfile
extends Resource
## Parámetros del inventario de un personaje. Valores en /data/inventory/*.tres.
## 🔶 Los umbrales de peso no están en el GDD: son placeholders de tuning.

## Bolsillos fijos: una rejilla por bolsillo (decisión de diseño: 4 de 1×1).
@export var pockets: Array[Vector2i] = []

@export_group("Peso")
## Por debajo de este peso no hay penalización.
@export var weight_penalty_start_kg: float = 0.0
## A este peso se alcanza la penalización máxima (sobrecarga).
@export var weight_max_kg: float = 0.0
## Multiplicador de velocidad con sobrecarga.
@export var overweight_speed_multiplier: float = 1.0
