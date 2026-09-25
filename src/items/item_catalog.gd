class_name ItemCatalog
extends Resource
## Lista de todas las definiciones de objetos del juego (data/items/catalog.tres).
## Sirve para buscar definiciones por id (partidas guardadas, red) o por munición.

const DEFAULT_PATH: String = "res://data/items/catalog.tres"

@export var items: Array[ItemDefinition] = []

var _by_id: Dictionary[StringName, ItemDefinition] = {}


static func load_default() -> ItemCatalog:
	return load(DEFAULT_PATH) as ItemCatalog


func get_item(id: StringName) -> ItemDefinition:
	if _by_id.is_empty():
		for def: ItemDefinition in items:
			_by_id[def.id] = def
	return _by_id.get(id) as ItemDefinition


## Definición de objeto de la caja/stack de una munición.
func item_for_ammo(ammo: AmmoDefinition) -> ItemDefinition:
	for def: ItemDefinition in items:
		if def.ammo == ammo:
			return def
	return null
