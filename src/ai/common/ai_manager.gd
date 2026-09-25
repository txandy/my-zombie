class_name AIManager
extends Node
## LOD de IA (GDD §11.2): simulación completa a menos de `full_range_m` de cualquier
## jugador, simplificada hasta `simplified_range_m` y congelada más allá.
## Solo en el host. Revisa las distancias a intervalos, no cada frame.

@export var full_range_m: float = 150.0
@export var simplified_range_m: float = 400.0
@export var check_interval_s: float = 0.5

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_interval_s
	update_lods()


func update_lods() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		var npc := node as HumanNPC
		if npc == null or npc.is_dead:
			continue
		apply_lod(npc, lod_for(npc.global_position, players))


func lod_for(position: Vector3, players: Array[Node]) -> int:
	var nearest: float = INF
	for player: Node in players:
		nearest = minf(nearest, (player as Node3D).global_position.distance_to(position))
	if nearest <= full_range_m:
		return 0
	return 1 if nearest <= simplified_range_m else 2


static func apply_lod(npc: HumanNPC, level: int) -> void:
	if npc.lod_level == level:
		return
	npc.lod_level = level
	# Congelado: ni percepción ni física. Simplificado: percibe más despacio.
	npc.perception.set_physics_process(level < 2)
	npc.perception.interval_multiplier = 1.0 if level == 0 else 3.0
	npc.set_physics_process(level < 2)
