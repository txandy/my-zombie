class_name WorldPersistence
## Captura y restaura el estado dinámico de una partida (GDD §13): día y hora, contenedores
## saqueados, objetos en el suelo, bases, NPCs (vivos y cadáveres), zombis y recursos
## gastados de árboles y rocas. El mundo en sí sale de la caché (WorldCache).
##
## `root` es la escena del mundo: necesita los hijos WorldBuilder, Buildings, NPCs y Zombies.


static func capture(root: Node) -> Dictionary:
	var tree: SceneTree = root.get_tree()
	var containers: Dictionary = {}
	for node: Node in tree.get_nodes_in_group(&"loot_container"):
		var container := node as LootContainer
		if container.is_filled:
			containers[String(container.container_id)] = ItemSerializer.container_to_list(container.item_container)
	var world_items: Array = []
	for node: Node in tree.get_nodes_in_group(&"world_item"):
		var world_item := node as WorldItem
		world_items.append({"item": ItemSerializer.item_to_dict(world_item.item), "pos": world_item.global_position})
	var npcs: Dictionary = {}
	for node: Node in tree.get_nodes_in_group(&"npc"):
		npcs[String(node.name)] = (node as HumanNPC).to_save()
	var zombies: Array = []
	for node: Node in tree.get_nodes_in_group(&"zombie"):
		var zombie := node as Zombie
		if zombie.state != Zombie.State.DEAD:
			zombies.append({"pos": zombie.global_position, "health": zombie.health.to_save()})
	var registry := tree.get_first_node_in_group(&"cover_registry") as CoverRegistry
	return {
		"day": GameState.day, "hour": GameState.hour,
		"containers": containers, "world_items": world_items,
		"bases": _capture_bases(root.get_node(^"Buildings") as BuildingManager),
		"npcs": npcs, "zombies": zombies,
		"resources": registry.export_resources() if registry != null else PackedFloat32Array(),
	}


static func _capture_bases(manager: BuildingManager) -> Array:
	var bases: Array = []
	for base: BaseModel in manager.bases:
		var pieces: Array = []
		for piece: BaseModel.Piece in base.pieces.values():
			pieces.append({"uid": piece.uid, "def": piece.definition.resource_path,
					"mat": piece.material.resource_path, "cell": piece.cell, "side": piece.side, "hp": piece.hp})
		bases.append({"id": base.id, "origin": base.origin, "pieces": pieces})
	return bases


static func apply(root: Node, state: Dictionary, catalog: ItemCatalog) -> void:
	var tree: SceneTree = root.get_tree()
	GameState.day = int(state.day)
	GameState.hour = float(state.hour)
	var registry := tree.get_first_node_in_group(&"cover_registry") as CoverRegistry
	if registry != null:
		registry.import_resources(state.resources)
	for node: Node in tree.get_nodes_in_group(&"loot_container"):
		var container := node as LootContainer
		if state.containers.has(String(container.container_id)):
			container.restore(state.containers[String(container.container_id)], catalog)
	for entry: Dictionary in state.world_items:
		var item: ItemInstance = ItemSerializer.item_from_dict(entry.item, catalog)
		if item != null:
			WorldItem.spawn(item, entry.pos as Vector3, root)
	_apply_bases(root.get_node(^"Buildings") as BuildingManager, state.bases)
	for node: Node in tree.get_nodes_in_group(&"npc"):
		if state.npcs.has(String(node.name)):
			(node as HumanNPC).from_save(state.npcs[String(node.name)], catalog)
	var director := root.get_node_or_null(^"Zombies") as ZombieDirector
	if director != null:
		for entry: Dictionary in state.zombies:
			var zombie: Zombie = director.spawn_zombie(entry.pos as Vector3)
			zombie.health.from_save(entry.health)


static func _apply_bases(manager: BuildingManager, bases: Array) -> void:
	for data: Dictionary in bases:
		var base := BaseModel.new(int(data.id), data.origin as Transform3D)
		for p: Dictionary in data.pieces:
			base.restore(load(p.def) as BuildingPieceDefinition, load(p.mat) as BuildingMaterial,
					p.cell as Vector3i, int(p.side), float(p.hp), int(p.uid))
		manager.restore_base(base)


static func capture_player(player: Player) -> Dictionary:
	return {"pos": player.global_position, "rot": player.rotation.y,
			"health": player.health.to_save(), "survival": ItemSerializer.survival_to_dict(player.survival),
			"inventory": ItemSerializer.inventory_to_dict(player.inventory)}


static func apply_player(player: Player, data: Dictionary, catalog: ItemCatalog) -> void:
	player.global_position = data.pos
	player.rotation.y = float(data.rot)
	player.health.from_save(data.health)
	ItemSerializer.survival_from_dict(player.survival, data.survival)
	ItemSerializer.inventory_from_dict(player.inventory, data.inventory, catalog)
