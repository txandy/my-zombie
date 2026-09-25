class_name PoiPlacement
extends RefCounted
## Un POI colocado por la generación.

## Índice en WorldGenSettings.poi_definitions.
var definition_index: int = 0
## Centro de la huella en coordenadas del mapa (m), con la altura ya aplanada.
var position: Vector3 = Vector3.ZERO
## Rotación en pasos de 90° (0-3) alrededor de Y.
var rotation_steps: int = 0


func _init(index: int = 0, pos: Vector3 = Vector3.ZERO, steps: int = 0) -> void:
	definition_index = index
	position = pos
	rotation_steps = steps


## Huella rotada (x, z) en metros.
func rotated_footprint(definition: PoiDefinition) -> Vector2:
	var f: Vector2 = definition.footprint_m
	return f if rotation_steps % 2 == 0 else Vector2(f.y, f.x)


func to_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(32)
	bytes.encode_s64(0, definition_index)
	bytes.encode_double(8, position.x)
	bytes.encode_double(16, position.y)
	bytes.encode_double(24, position.z)
	bytes.append(rotation_steps)
	return bytes
