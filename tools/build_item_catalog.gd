extends SceneTree
## Regenera data/items/catalog.tres con todas las definiciones de data/items/.
## Uso: godot --headless --path . -s res://tools/build_item_catalog.gd
## (El test test_catalog_contains_every_item falla si el catálogo se queda desactualizado.)


func _init() -> void:
	var catalog := ItemCatalog.new()
	var dir := DirAccess.open("res://data/items")
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		if file.ends_with(".tres") and file != "catalog.tres":
			var def := load("res://data/items/" + file) as ItemDefinition
			if def != null:
				catalog.items.append(def)
	var err: Error = ResourceSaver.save(catalog, ItemCatalog.DEFAULT_PATH)
	print("Catálogo: %d objetos · %s" % [catalog.items.size(), error_string(err)])
	quit()
