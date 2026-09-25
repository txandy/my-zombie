# El catálogo debe contener todas las definiciones de data/items (si falla, regenerar
# con tools/build_item_catalog.gd).
extends GdUnitTestSuite


func test_catalog_contains_every_item() -> void:
	var catalog: ItemCatalog = ItemCatalog.load_default()
	var dir := DirAccess.open("res://data/items")
	for file: String in dir.get_files():
		if not file.ends_with(".tres") or file == "catalog.tres":
			continue
		var def := load("res://data/items/" + file) as ItemDefinition
		assert_object(catalog.get_item(def.id)).override_failure_message(
			"Falta '%s' en el catálogo: ejecuta tools/build_item_catalog.gd" % def.id).is_same(def)


func test_ammo_lookup() -> void:
	var catalog: ItemCatalog = ItemCatalog.load_default()
	var ammo := load("res://data/combat/ammo/9x19_pst.tres") as AmmoDefinition
	assert_str(String(catalog.item_for_ammo(ammo).id)).is_equal("ammo_9x19_pst")
