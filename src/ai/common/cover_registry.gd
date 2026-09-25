class_name CoverRegistry
extends Node
## Obstáculos del terreno que sirven de cobertura (troncos, rocas), en celdas para
## consultas rápidas. Lo rellena WorldBuilder con la vegetación con colisión.

const CELL_M: float = 16.0

## Celda -> [x, z, radio, alto, ...] de cada obstáculo.
var _cells: Dictionary[Vector2i, PackedFloat32Array] = {}


func _ready() -> void:
	add_to_group(&"cover_registry")


func add_obstacle(position: Vector3, radius: float, height: float) -> void:
	var key := Vector2i(floori(position.x / CELL_M), floori(position.z / CELL_M))
	if not _cells.has(key):
		_cells[key] = PackedFloat32Array()
	_cells[key].append_array(PackedFloat32Array([position.x, position.z, radius, height]))


## Obstáculos a menos de `radius_m` de `point`: {"position", "radius", "height"}.
func obstacles_near(point: Vector3, radius_m: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var reach: int = ceili(radius_m / CELL_M)
	var center := Vector2i(floori(point.x / CELL_M), floori(point.z / CELL_M))
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var data: PackedFloat32Array = _cells.get(center + Vector2i(dx, dz), PackedFloat32Array())
			for i: int in range(0, data.size(), 4):
				var p := Vector3(data[i], point.y, data[i + 1])
				if Vector2(p.x - point.x, p.z - point.z).length() <= radius_m:
					result.append({"position": p, "radius": data[i + 2], "height": data[i + 3]})
	return result
