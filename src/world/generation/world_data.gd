class_name WorldData
extends RefCounted
## Resultado de la generación del mundo: solo datos, sin nodos (GDD §4.2).
##
## Las rejillas son de resolution × resolution muestras, en orden fila a fila:
## índice = z * resolution + x. La muestra (x, z) está en el punto (x, z) * cell_size_m
## con el origen en la esquina del mapa.

var world_seed: int = 0
var resolution: int = 0
var cell_size_m: float = 1.0

## Fase 1: altura en metros.
var heights := PackedFloat32Array()
## Fase 2: temperatura y humedad normalizadas (0-1).
var temperature := PackedFloat32Array()
var humidity := PackedFloat32Array()
## Fase 3: índice del bioma en WorldGenSettings.biomes.
var biomes := PackedByteArray()
## Fase 5: POIs colocados, en orden de colocación.
var pois: Array[PoiPlacement] = []
## Fase 8: una lista de instancias por capa de vegetación (VegetationPhase.STRIDE floats cada una).
var vegetation: Array[PackedFloat32Array] = []
## Fase 9: aparición del jugador y campamentos de NPCs.
var spawns: SpawnData

## Tiempo de cada fase en ms. No forma parte del hash.
var timings: Dictionary[StringName, int] = {}


func index(x: int, z: int) -> int:
	return z * resolution + x


func height_at(x: int, z: int) -> float:
	return heights[index(x, z)]


## SHA-256 (hex) de todos los datos generados. La misma seed y los mismos
## ajustes deben dar siempre el mismo hash (AGENTS.md §1.2).
func compute_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var header := PackedByteArray()
	header.resize(24)
	header.encode_s64(0, world_seed)
	header.encode_s64(8, resolution)
	header.encode_double(16, cell_size_m)
	ctx.update(header)
	# Longitud antes de cada bloque para que dos bloques no puedan "desplazarse" entre sí.
	for grid: PackedByteArray in [heights.to_byte_array(), temperature.to_byte_array(),
			humidity.to_byte_array(), biomes]:
		_update_with_length(ctx, grid)
	_update_count(ctx, pois.size())
	for poi: PoiPlacement in pois:
		ctx.update(poi.to_bytes())
	_update_count(ctx, vegetation.size())
	for layer: PackedFloat32Array in vegetation:
		_update_with_length(ctx, layer.to_byte_array())
	if spawns != null:
		_update_with_length(ctx, spawns.to_bytes())
	return ctx.finish().hex_encode()


static func _update_count(ctx: HashingContext, count: int) -> void:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, count)
	ctx.update(bytes)


static func _update_with_length(ctx: HashingContext, block: PackedByteArray) -> void:
	_update_count(ctx, block.size())
	ctx.update(block)
