class_name BiomeDefinition
extends Resource
## Definición de un bioma (GDD §4.3). Los valores viven en /data/biomes/*.tres.

@export var id: StringName = &""
@export var display_name: String = ""
## Dificultad del bioma (1-4). Escala amenazas y loot.
@export_range(1, 4) var difficulty: int = 1

@export_group("Asignación")
## Clima "ideal" del bioma: x = temperatura, y = humedad (ambos 0-1).
## A cada celda se le asigna el bioma con el centro más cercano a su clima.
@export var climate_center: Vector2 = Vector2.ZERO
## Rango de alturas (m) en el que puede aparecer.
@export var min_height: float = -1000.0
@export var max_height: float = 1000.0

@export_group("Depuración")
## Color en el mapa de biomas de depuración y en el splat provisional.
@export var debug_color: Color = Color.MAGENTA
