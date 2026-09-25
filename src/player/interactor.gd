class_name Interactor
extends Node
## Interacción del jugador con E: detecta a qué apunta la cámara (capa "interactables")
## y pide al host que interactúe. El host revalida la distancia (AGENTS.md §1.1).
## Un interactuable es cualquier nodo con interaction_text() e interact(player).

@export var reach_m: float = 2.5
## Margen extra que acepta el host (latencia, diferencias de posición).
@export var server_reach_margin_m: float = 1.0

## Objetivo al que apunta ahora (para el texto del HUD), o null.
var focused: Node3D

@onready var _player: Player = get_parent() as Player


func _physics_process(_delta: float) -> void:
	focused = _find_target()


func _find_target() -> Node3D:
	var cam: Camera3D = _player.camera()
	var from: Vector3 = cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * reach_m,
			PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLES, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node3D
	if collider == null or not collider.has_method(&"interact"):
		return null
	return collider if String(collider.call(&"interaction_text")) != "" else null


func request_interact() -> void:
	if focused != null:
		_server_interact.rpc_id(1, focused.get_path())


@rpc("any_peer", "call_local", "reliable")
func _server_interact(target_path: NodePath) -> void:
	if not multiplayer.is_server() or _player.health.is_dead:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != _player.inventory.owner_peer_id and sender != 0:
		return
	var target := get_node_or_null(target_path) as Node3D
	if target == null or not target.has_method(&"interact"):
		return
	if target.global_position.distance_to(_player.global_position) > reach_m + server_reach_margin_m + 1.0:
		return
	target.call(&"interact", _player)
