class_name BuildingMaterial
extends Resource
## Material de construcción por tier (GDD §10): madera, piedra, metal, reforzado.
## Valores en /data/building/materials/*.tres. 🔶 Costes y vida: placeholders de tuning.

@export var id: StringName = &""
@export var display_name: String = ""
## Orden de mejora (0 = madera). Solo se puede mejorar a un tier superior.
@export var tier: int = 0
## Objeto que se gasta al construir o mejorar con este material.
@export var resource_item: ItemDefinition
## Vida de una pieza "de referencia" (pared). Cada tipo de pieza la multiplica.
@export var base_hp: float = 0.0
## Unidades del recurso para una pieza de referencia. Cada tipo de pieza lo multiplica.
@export var base_cost: int = 0
@export var color: Color = Color.WHITE
