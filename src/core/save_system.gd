extends Node
## Guardado y carga de partidas (autoload `SaveSystem`). GDD §13.
##
## Esqueleto de M0: define la versión del formato y la ubicación de las partidas.
## La serialización real llega en M6.

## Versión del formato de guardado. Súbela cuando cambie el formato y añade su migración.
const SAVE_VERSION: int = 1
const SAVES_ROOT: String = "user://saves"


## Carpeta de la partida `save_name`. El nombre se sanea para que sea un nombre de archivo válido.
func get_save_dir(save_name: String) -> String:
	var safe_name: String = save_name.strip_edges().validate_filename()
	if safe_name.is_empty():
		safe_name = "unnamed"
	return SAVES_ROOT.path_join(safe_name)
