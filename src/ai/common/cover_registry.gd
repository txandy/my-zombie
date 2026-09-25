class_name CoverRegistry
extends Node
## Obstáculos del terreno (troncos, rocas), en celdas para consultas rápidas. Sirven de
## cobertura a la IA y de fuente de recursos (madera, piedra) al jugador.
## Lo rellena WorldBuilder con la vegetación con colisión.

enum Kind { TREE, ROCK }

const CELL_M: float = 16.0
## Floats por obstáculo: x, z, radio, alto, tipo, recursos restantes.
const STRIDE: int = 6

## Celda -> datos de sus obstáculos.
var _cells: Dictionary[Vector2i, PackedFloat32Array] = {}


func _ready() -> void:
	add_to_group(&"cover_registry")


func add_obstacle(position: Vector3, radius: float, height: float, kind: Kind = Kind.TREE, resources: int = 0) -> void:
	var key := _key(position)
	if not _cells.has(key):
		_cells[key] = PackedFloat32Array()
	_cells[key].append_array(PackedFloat32Array([position.x, position.z, radius, height, kind, resources]))


## Obstáculos a menos de `radius_m` de `point`:
## {"position", "radius", "height", "kind", "resources"}.
func obstacles_near(point: Vector3, radius_m: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var reach: int = ceili(radius_m / CELL_M)
	var center: Vector2i = _key(point)
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var data: PackedFloat32Array = _cells.get(center + Vector2i(dx, dz), PackedFloat32Array())
			for i: int in range(0, data.size(), STRIDE):
				var p := Vector3(data[i], point.y, data[i + 1])
				if Vector2(p.x - point.x, p.z - point.z).length() <= radius_m:
					result.append({"position": p, "radius": data[i + 2], "height": data[i + 3],
							"kind": int(data[i + 4]), "resources": int(data[i + 5])})
	return result


## Quita hasta `amount` recursos del obstáculo más cercano a `point` (a menos de
## `max_distance_m` de su superficie). Devuelve {"kind", "taken"} o {} si no hay.
func take_resources(point: Vector3, max_distance_m: float, amount: int) -> Dictionary:
	var center: Vector2i = _key(point)
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var key: Vector2i = center + Vector2i(dx, dz)
			var data: PackedFloat32Array = _cells.get(key, PackedFloat32Array())
			for i: int in range(0, data.size(), STRIDE):
				var surface: float = Vector2(data[i] - point.x, data[i + 1] - point.z).length() - data[i + 2]
				if surface <= max_distance_m and data[i + 5] > 0.0:
					var taken: int = mini(amount, int(data[i + 5]))
					data[i + 5] -= taken
					_cells[key] = data
					return {"kind": int(data[i + 4]), "taken": taken}
	return {}


func _key(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL_M), floori(point.z / CELL_M))


## Recursos restantes de todos los obstáculos, en orden estable (para guardar partida).
## El orden depende solo de cómo se construyó el registro desde WorldData, que es el mismo
## al cargar la partida.
func export_resources() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for key: Vector2i in _cells:
		var data: PackedFloat32Array = _cells[key]
		for i: int in range(0, data.size(), STRIDE):
			result.append(data[i + 5])
	return result


func import_resources(values: PackedFloat32Array) -> void:
	var n: int = 0
	for key: Vector2i in _cells:
		var data: PackedFloat32Array = _cells[key]
		for i: int in range(0, data.size(), STRIDE):
			if n < values.size():
				data[i + 5] = values[n]
			n += 1
		_cells[key] = data
