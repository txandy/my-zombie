class_name CampSpawner
## Crea escuadras de NPCs (campamentos) a partir de SpawnData (GDD §4.2 fase 9).
## Los nombres de los NPCs son estables para que su equipo (sembrado por nombre y seed)
## sea el mismo en cada carga de la partida.


## Crea la escuadra del campamento `index` bajo `parent`. Los miembros se colocan en
## círculo alrededor del campamento a la altura dada por `height_at` (Callable(Vector3) -> float).
static func spawn_camp(parent: Node, camp: SpawnData.Camp, index: int, archetype: NpcArchetype,
		height_at: Callable) -> Squad:
	var scene := load(archetype.scene_path) as PackedScene
	var squad := Squad.new()
	squad.name = "Camp%d" % index
	for m: int in camp.members:
		var npc := scene.instantiate() as HumanNPC
		npc.name = "Camp%d_%s%d" % [index, archetype.id.capitalize(), m]
		var angle: float = TAU * m / float(camp.members)
		var spot: Vector3 = camp.position + Vector3(cos(angle), 0.0, sin(angle)) * 8.0
		spot.y = float(height_at.call(spot)) + 0.3
		npc.position = spot
		squad.add_child(npc)
	# Se añade al árbol con los miembros ya dentro: así Squad._ready los registra.
	parent.add_child(squad)
	return squad
