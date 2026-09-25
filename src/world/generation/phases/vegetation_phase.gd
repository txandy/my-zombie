class_name VegetationPhase
extends WorldGenPhase
## Fase 8: vegetación y rocas. Rejilla con jitter por capa; cada celda tiene instancia
## según la densidad del bioma, y se excluyen agua, pendientes fuertes y POIs. Las capas
## con clearance_radius_m se reservan espacio entre sí (en el orden de las capas) para
## que el bosque sea transitable. GDD §4.2.
##
## Cada celda consume siempre los mismos números del RNG, pase o no los filtros,
## para que los resultados no dependan del orden en que fallan las comprobaciones.

## Floats por instancia en WorldData.vegetation: x, y, z, rotación Y (rad), escala.
const STRIDE: int = 5
## Celda del hash espacial de holguras. Debe ser >= 2 × el mayor clearance_radius_m.
const CLEARANCE_CELL_M: float = 8.0

var _poi_rects: Array[Rect2] = []
## Instancias con holgura ya colocadas (de todas las capas): celda -> [x, z, radio, ...].
var _reserved: Dictionary[Vector2i, PackedFloat32Array] = {}


func phase_name() -> StringName:
	return &"vegetation"


func run(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	data.vegetation.clear()
	_reserved.clear()
	for layer: VegetationLayer in settings.vegetation_layers:
		_poi_rects = _build_poi_rects(data, settings, layer.poi_clearance_m)
		data.vegetation.append(_place_layer(data, settings, layer, rng))


func _place_layer(data: WorldData, settings: WorldGenSettings, layer: VegetationLayer,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var size: float = (data.resolution - 1) * data.cell_size_m
	var cells: int = floori(size / layer.spacing_m)
	for gz: int in cells:
		for gx: int in cells:
			var jx: float = rng.randf()
			var jz: float = rng.randf()
			var roll: float = rng.randf()
			var rot: float = rng.randf() * TAU
			var scale: float = lerpf(layer.min_scale, layer.max_scale, rng.randf())
			var offset: float = (1.0 - layer.jitter) * 0.5
			var wx: float = (gx + offset + jx * layer.jitter) * layer.spacing_m
			var wz: float = (gz + offset + jz * layer.jitter) * layer.spacing_m
			var y: float = _accept(data, settings, layer, wx, wz, roll)
			if not is_nan(y) and _reserve(layer.clearance_radius_m, wx, wz):
				out.append_array(PackedFloat32Array([wx, y, wz, rot, scale]))
	return out


## Altura del terreno en (wx, wz) si la instancia se acepta; NAN si se descarta.
func _accept(data: WorldData, settings: WorldGenSettings, layer: VegetationLayer,
		wx: float, wz: float, roll: float) -> float:
	var x: int = clampi(roundi(wx / data.cell_size_m), 1, data.resolution - 2)
	var z: int = clampi(roundi(wz / data.cell_size_m), 1, data.resolution - 2)
	var biome_id: StringName = settings.biomes[data.biomes[data.index(x, z)]].id
	if roll >= layer.biome_density.get(biome_id, 0.0):
		return NAN
	var h: float = data.height_at(x, z)
	if h < layer.min_height or _gradient(data, x, z) > layer.max_gradient:
		return NAN
	var point := Vector2(wx, wz)
	for rect: Rect2 in _poi_rects:
		if rect.has_point(point):
			return NAN
	return h


## Reserva la holgura de la instancia si no choca con otra. Sin holgura, siempre se acepta.
func _reserve(radius: float, wx: float, wz: float) -> bool:
	if radius <= 0.0:
		return true
	var cell := Vector2i(floori(wx / CLEARANCE_CELL_M), floori(wz / CLEARANCE_CELL_M))
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var others: PackedFloat32Array = _reserved.get(cell + Vector2i(dx, dz), PackedFloat32Array())
			for i: int in range(0, others.size(), 3):
				var min_distance: float = radius + others[i + 2]
				if Vector2(wx, wz).distance_squared_to(Vector2(others[i], others[i + 1])) < min_distance * min_distance:
					return false
	if not _reserved.has(cell):
		_reserved[cell] = PackedFloat32Array()
	_reserved[cell].append_array(PackedFloat32Array([wx, wz, radius]))
	return true


# Desnivel por metro (máximo de los dos ejes) con diferencias centradas.
func _gradient(data: WorldData, x: int, z: int) -> float:
	var span: float = 2.0 * data.cell_size_m
	var gx: float = absf(data.height_at(x + 1, z) - data.height_at(x - 1, z)) / span
	var gz: float = absf(data.height_at(x, z + 1) - data.height_at(x, z - 1)) / span
	return maxf(gx, gz)


# Huellas de los POIs ampliadas con su margen de aplanado y la holgura de la capa.
func _build_poi_rects(data: WorldData, settings: WorldGenSettings, clearance: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for poi: PoiPlacement in data.pois:
		var def: PoiDefinition = settings.poi_definitions[poi.definition_index]
		var half: Vector2 = poi.rotated_footprint(def) * 0.5 + Vector2.ONE * (def.flatten_margin_m + clearance)
		rects.append(Rect2(Vector2(poi.position.x, poi.position.z) - half, half * 2.0))
	return rects
