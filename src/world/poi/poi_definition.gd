class_name PoiDefinition
extends Resource
## Reglas de colocación de un POI (GDD §4.4). Los valores viven en /data/poi/*.tres.
##
## La escena del POI tiene el origen en el centro de la huella, a nivel de suelo,
## con la entrada mirando a -Z. Sus marcadores de loot, spawn y cobertura van dentro de la escena.

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
## 1: casas, gasolineras · 2: supermercados, granjas · 3: comisarías · 4: militares.
@export_range(1, 4) var tier: int = 1

@export_group("Colocación")
## Huella en metros: x = ancho, y = fondo (antes de rotar).
@export var footprint_m: Vector2 = Vector2.ZERO
## Ids de BiomeDefinition donde puede aparecer.
@export var allowed_biomes: Array[StringName] = []
## Diferencia máxima de altura del terreno bajo la huella antes de aplanar.
## Se usa en lugar de un ángulo para no depender de funciones trigonométricas (determinismo).
@export var max_height_variation_m: float = 0.0
## Separación mínima entre el borde de este POI y el de cualquier otro.
@export var min_distance_m: float = 0.0
## Número máximo de instancias en el mundo.
@export var max_count: int = 0
## Franja alrededor de la huella en la que el aplanado se funde con el terreno.
@export var flatten_margin_m: float = 0.0


## Radio del círculo que contiene la huella (para comprobar distancias).
func bounding_radius() -> float:
	return footprint_m.length() * 0.5
