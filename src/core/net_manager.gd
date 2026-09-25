extends Node
## Gestión de la red (autoload `NetManager`). GDD §12.
##
## Siempre hay un host con autoridad. El single player es un host sin clientes:
## usa el mismo camino de código que el coop, solo cambia el peer.
##
## Modo de sesión (lo fija el menú o la línea de comandos: --host, --join=IP, --name=X):
##   SINGLE: host local sin red · HOST: listen server · CLIENT: se conecta a un host.
## Un cliente está "listo" cuando ha regenerado el mundo desde la seed y comprobado su
## hash; solo entonces se le replican jugadores, zombis, objetos y estado.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
## Un cliente ha terminado de construir su mundo (host).
signal peer_ready(peer_id: int)

enum Mode { SINGLE, HOST, CLIENT }

const HOST_PEER_ID: int = 1
## Coop de 2-4 jugadores (GDD §2): el host más 3 clientes.
const MAX_CLIENTS: int = 3
## 🔶 Puerto provisional; no está definido en el GDD.
const DEFAULT_PORT: int = 24570

var mode: Mode = Mode.SINGLE
var join_address: String = "127.0.0.1"
var port: int = DEFAULT_PORT
## Nombre del jugador local (identifica su archivo de guardado en el host).
var player_name: String = "Jugador"
## Host: peers que ya tienen el mundo construido, y sus nombres.
var ready_peers: Dictionary[int, bool] = {}
var peer_names: Dictionary[int, String] = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--host":
			mode = Mode.HOST
		elif arg.begins_with("--join="):
			mode = Mode.CLIENT
			join_address = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--name="):
			player_name = arg.trim_prefix("--name=")


## Arranca la red según el modo. Lo llama la escena del mundo al empezar.
func begin_session() -> Error:
	ready_peers.clear()
	peer_names.clear()
	match mode:
		Mode.HOST:
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.is_server():
				return OK
			return host(port)
		Mode.CLIENT:
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				return OK
			return join(join_address, port)
	start_single_player()
	return OK


## Single player: host local sin red.
func start_single_player() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Coop: abre un listen server en `listen_port`.
func host(listen_port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(listen_port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Coop: se conecta a un host.
func join(address: String, host_port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, host_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Cierra la conexión y vuelve al modo sin red.
func close() -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	ready_peers.clear()
	peer_names.clear()


## True si esta instancia tiene la autoridad del juego.
func is_host() -> bool:
	return multiplayer.is_server()


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


## Host: un peer ya puede recibir la replicación del mundo.
func mark_ready(peer_id: int) -> void:
	ready_peers[peer_id] = true
	for node: Node in get_tree().get_nodes_in_group(&"net_sync"):
		(node as MultiplayerSynchronizer).update_visibility(peer_id)
	peer_ready.emit(peer_id)


## Filtro de visibilidad para los MultiplayerSynchronizer: el host (y peers aún sin mundo)
## no reciben replicación hasta estar listos.
func is_peer_ready(peer_id: int) -> bool:
	return peer_id == HOST_PEER_ID or ready_peers.has(peer_id)


## IDs de los clientes listos (sin el host).
func ready_clients() -> Array[int]:
	var result: Array[int] = []
	for peer_id: int in ready_peers:
		if peer_id != HOST_PEER_ID:
			result.append(peer_id)
	return result


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	ready_peers.erase(peer_id)
	peer_names.erase(peer_id)
	peer_left.emit(peer_id)
