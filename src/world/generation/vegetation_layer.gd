class_name VegetationLayer
extends Resource
## Un tipo de vegetación o roca instanciado con MultiMesh (GDD §4.2, fase 8).
## Los valores viven en /data/vegetation/*.tres.

@export var id: StringName = &""
## Malla de la instancia (placeholder hasta tener arte).
@export var mesh: Mesh

@export_group("Distribución")
## Separación de la rejilla de candidatos (m). Como mucho, una instancia por celda.
@export var spacing_m: float = 0.0
## Desplazamiento aleatorio dentro de la celda, como fracción de spacing_m (0-1).
@export_range(0.0, 1.0) var jitter: float = 0.0
## Probabilidad (0-1) de que una celda tenga instancia, por id de bioma. Sin entrada = 0.
@export var biome_density: Dictionary[StringName, float] = {}
## Altura mínima del terreno (evita el agua).
@export var min_height: float = 0.0
## Pendiente máxima como desnivel por metro (0.5 ≈ 27°). Sin trigonometría, por determinismo.
@export var max_gradient: float = 0.0
## Distancia libre alrededor de la huella de los POIs.
@export var poi_clearance_m: float = 0.0

@export_group("Instancia")
@export var min_scale: float = 1.0
@export var max_scale: float = 1.0

@export_group("Colisión")
## Radio del cilindro de colisión con escala 1. 0 = sin colisión (hierba, arbustos).
@export var collision_radius: float = 0.0
@export var collision_height: float = 0.0
