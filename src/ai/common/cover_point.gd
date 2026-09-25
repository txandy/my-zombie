class_name CoverPoint
extends Marker3D
## Punto de cobertura hecho a mano en un POI (GDD §4.4). `low` = cobertura baja
## (hay que agacharse); si no, cobertura alta (se asoma de lado).

@export var low: bool = true


func _ready() -> void:
	add_to_group(&"cover_point")
