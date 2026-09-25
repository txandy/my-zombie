class_name SpawnData
extends RefCounted
## Resultado de la fase 9 (spawns): aparición del jugador y campamentos de NPCs.

class Camp:
	extends RefCounted
	var position: Vector3
	## Índice en WorldGenSettings.npc_archetypes.
	var archetype_index: int = 0
	var members: int = 1
	## Índice del POI junto al que está (-1 si ninguno).
	var poi_index: int = -1


var player_spawn: Vector3
var camps: Array[Camp] = []
## Puntos donde pueden aparecer zombis (en tierra, fuera de POIs y lejos de la aparición).
var zombie_points := PackedVector3Array()


func to_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(32)
	bytes.encode_double(0, player_spawn.x)
	bytes.encode_double(8, player_spawn.y)
	bytes.encode_double(16, player_spawn.z)
	bytes.encode_s64(24, camps.size())
	var zombie_bytes: PackedByteArray = zombie_points.to_byte_array()
	for camp: Camp in camps:
		var chunk := PackedByteArray()
		chunk.resize(48)
		chunk.encode_double(0, camp.position.x)
		chunk.encode_double(8, camp.position.y)
		chunk.encode_double(16, camp.position.z)
		chunk.encode_s64(24, camp.archetype_index)
		chunk.encode_s64(32, camp.members)
		chunk.encode_s64(40, camp.poi_index)
		bytes.append_array(chunk)
	bytes.append_array(zombie_bytes)
	return bytes
