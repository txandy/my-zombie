class_name NetSync
## Crea MultiplayerSynchronizer por código (GDD §12). Todos quedan en el grupo "net_sync"
## y solo replican a los peers listos (que ya tienen su mundo construido).


## Sincroniza las `properties` de `root` (rutas relativas a root, p. ej. ":position").
## `always`: replicar cada tick (movimiento); si no, solo al cambiar.
static func add(root: Node, properties: Array[String], authority: int = 1, always: bool = true,
		interval_s: float = 0.0) -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for property: String in properties:
		var path := NodePath(property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path,
				SceneReplicationConfig.REPLICATION_MODE_ALWAYS if always else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config
	sync.replication_interval = interval_s
	sync.add_visibility_filter(NetManager.is_peer_ready)
	sync.add_to_group(&"net_sync")
	root.add_child(sync)
	sync.root_path = sync.get_path_to(root)
	sync.set_multiplayer_authority(authority)
	return sync
