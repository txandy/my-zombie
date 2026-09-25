class_name NpcArchetype
extends Resource
## Arquetipo de NPC que puede aparecer en el mundo (GDD §11.2). Valores en /data/ai/*.tres.
## 🔶 Lista de arquetipos abierta en el GDD (§18.2): en M4 solo el bandido.

@export var id: StringName = &""
## Ruta de la escena del NPC. Es una ruta y no un PackedScene para que la generación del
## mundo (datos puros) no cargue escenas ni scripts de juego.
@export_file("*.tscn") var scene_path: String = ""
## Tamaño de la escuadra (rango inclusivo).
@export var squad_min: int = 1
@export var squad_max: int = 1
## Ids de bioma donde puede tener campamento. Vacío = en todos.
@export var biomes: Array[StringName] = []
