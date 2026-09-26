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


func _physics_process(delta: float) -> void:
	_gather_cooldown = maxf(_gather_cooldown - delta, 0.0)
	focused = _find_target()


func _find_target() -> Node3D:
	var cam: Camera3D = _player.camera()
	var from: Vector3 = cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * reach_m,
			PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLES, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	_update_gather(hit)
	var collider := hit.get("collider") as Node3D
	if collider == null or not collider.has_method(&"interact"):
		return null
	return collider if String(collider.call(&"interaction_text")) != "" else null


func request_interact() -> void:
	if focused != null:
		_server_interact.rpc_id(1, focused.get_path())
	elif gather_kind >= 0:
		_server_gather.rpc_id(1, gather_point)


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


# --- Recoger recursos (madera de los árboles, piedra de las rocas) ---

## Unidades por recogida y pausa entre recogidas.
const GATHER_AMOUNT: int = 5
const GATHER_COOLDOWN_S: float = 0.8

## Punto de un árbol o roca al que apunta (si no hay otro interactuable).
var gather_point: Vector3
var gather_kind: int = -1

var _gather_cooldown: float = 0.0


func _registry() -> CoverRegistry:
	return get_tree().get_first_node_in_group(&"cover_registry") as CoverRegistry


## Detecta si apunta a un tronco o una roca con recursos (colisión de servidor sin nodo).
func _update_gather(hit: Dictionary) -> void:
	gather_kind = -1
	var registry := _registry()
	if registry == null or hit.is_empty() or hit.get("collider") != null:
		return
	for obstacle: Dictionary in registry.obstacles_near(hit.position as Vector3, 2.0):
		if int(obstacle.resources) > 0:
			gather_point = hit.position as Vector3
			gather_kind = int(obstacle.kind)
			return


func gather_text() -> String:
	if gather_kind == CoverRegistry.Kind.TREE:
		return "Talar (madera)"
	if gather_kind == CoverRegistry.Kind.ROCK:
		return "Picar (piedra)"
	return ""


@rpc("any_peer", "call_local", "reliable")
func _server_gather(point: Vector3) -> void:
	if not multiplayer.is_server() or _player.health.is_dead or _gather_cooldown > 0.0:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != _player.inventory.owner_peer_id and sender != 0:
		return
	if point.distance_to(_player.global_position) > reach_m + server_reach_margin_m + 1.0:
		return
	var registry := _registry()
	var taken: Dictionary = registry.take_resources(point, 1.5, GATHER_AMOUNT) if registry != null else {}
	if taken.is_empty():
		return
	_gather_cooldown = GATHER_COOLDOWN_S
	var item_id: String = "stone" if int(taken.kind) == CoverRegistry.Kind.ROCK else "wood"
	var def: ItemDefinition = ItemCatalog.load_default().get_item(StringName(item_id))
	var leftover: int = _player.inventory.give(ItemInstance.new(def, int(taken.taken)))
	if leftover > 0:
		_player.inventory.request_rejected.emit("no te cabe más %s" % def.display_name.to_lower())
	EventBus.sound_emitted.emit(point, 20.0, StringName("gather_" + item_id), _player)
