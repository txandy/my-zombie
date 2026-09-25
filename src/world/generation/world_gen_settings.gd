class_name WorldGenSettings
extends Resource
## Parámetros de la generación del mundo (GDD §4.1-4.2). Los valores viven en /data/world/*.tres.
## Todas las distancias están en metros y las frecuencias en ciclos por metro.

@export_group("Mapa")
@export var world_size_m: int = 0
## Separación entre muestras del heightmap.
@export var cell_size_m: float = 1.0

@export_group("Heightmap")
@export var base_height: float = 0.0
@export var continental_frequency: float = 0.0
@export var continental_amplitude: float = 0.0
@export var mountain_frequency: float = 0.0
@export var mountain_amplitude: float = 0.0
## Valor continental (0-1) a partir del cual empiezan a aparecer montañas.
@export var mountain_threshold: float = 0.0
@export var detail_frequency: float = 0.0
@export var detail_amplitude: float = 0.0
## Anchura de la franja de costa en los bordes del mapa.
@export var coast_width_m: float = 0.0
## Altura del fondo marino fuera del mapa jugable.
@export var sea_floor_height: float = 0.0

@export_group("Clima")
@export var temperature_frequency: float = 0.0
@export var humidity_frequency: float = 0.0
## Descenso de temperatura (0-1) por metro de altura.
@export var temperature_lapse_per_m: float = 0.0

@export_group("Biomas")
@export var biomes: Array[BiomeDefinition] = []

@export_group("POIs")
@export var poi_definitions: Array[PoiDefinition] = []
## Intentos de colocación por cada instancia pedida (max_count).
@export var poi_attempts_per_instance: int = 0
## Altura mínima del terreno bajo la huella (evita costa y agua).
@export var poi_min_height: float = 0.0

@export_group("Vegetación")
## Capas en orden de generación. Reordenarlas cambia el mundo.
@export var vegetation_layers: Array[VegetationLayer] = []

@export_group("Spawns")
@export var npc_archetypes: Array[NpcArchetype] = []
## Campamentos de NPCs a colocar.
@export var npc_camp_count: int = 0
## Distancia mínima entre un campamento y la aparición del jugador.
@export var npc_camp_min_distance_m: float = 0.0


## Número de muestras por lado del heightmap.
func resolution() -> int:
	return int(world_size_m / cell_size_m)
