extends Node
## Gestión de la red (autoload `NetManager`). GDD §12.
##
## Siempre hay un host con autoridad. El single player es un host sin clientes:
## usa el mismo camino de código que el coop, solo cambia el peer.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const HOST_PEER_ID: int = 1
## Coop de 2-4 jugadores (GDD §2): el host más 3 clientes.
const MAX_CLIENTS: int = 3
## 🔶 Puerto provisional; no está definido en el GDD.
const DEFAULT_PORT: int = 24570


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Single player: host local sin red.
func start_single_player() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Coop: abre un listen server en `port`.
func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Coop: se conecta a un host.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
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


## True si esta instancia tiene la autoridad del juego.
func is_host() -> bool:
	return multiplayer.is_server()


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)
