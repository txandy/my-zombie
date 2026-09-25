extends Node
## Guardado y carga de partidas (autoload `SaveSystem`). GDD §13.
##
## Carpeta de la partida (user://saves/<nombre>/):
##   meta.json         versión, seed, día, fecha (legible)
##   world.bin         caché del mundo generado (no se regenera al cargar)
##   state.bin         estado dinámico (contenedores, bases, NPCs, zombis, día y hora...)
##   players/<id>.bin  un archivo por jugador
## Los .bin usan var_to_bytes/bytes_to_var sin objetos: conservan los tipos de Godot y
## cargar un archivo no puede ejecutar código.
## Formato versionado (SAVE_VERSION) con migraciones encadenadas al cargar.

## Versión del formato de guardado. Súbela cuando cambie el formato y añade su migración.
const SAVE_VERSION: int = 1
const SAVES_ROOT: String = "user://saves"

## Migraciones: versión de origen -> Callable(state: Dictionary) -> Dictionary.
## Ejemplo al pasar a v2: MIGRATIONS[1] = _migrate_1_to_2.
var migrations: Dictionary[int, Callable] = {}

## Partida a cargar al entrar en el mundo (la fija el menú). "" = partida nueva.
var pending_load: String = ""
## Seed para una partida nueva (0 = aleatoria).
var pending_seed: int = 0
## Nombre de la partida en curso.
var current_save: String = ""


## Carpeta de la partida `save_name`. El nombre se sanea para que sea un nombre de archivo válido.
func get_save_dir(save_name: String) -> String:
	var safe_name: String = save_name.strip_edges().validate_filename()
	if safe_name.is_empty():
		safe_name = "unnamed"
	return SAVES_ROOT.path_join(safe_name)


func exists(save_name: String) -> bool:
	return FileAccess.file_exists(get_save_dir(save_name).path_join("meta.json"))


## Partidas guardadas, de la más reciente a la más antigua: [{name, meta}].
func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(SAVES_ROOT)
	if dir == null:
		return result
	for save_name: String in dir.get_directories():
		var meta: Dictionary = read_meta(save_name)
		if not meta.is_empty():
			result.append({"name": save_name, "meta": meta})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.meta.get("saved_at", 0)) > int(b.meta.get("saved_at", 0)))
	return result


func read_meta(save_name: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(get_save_dir(save_name).path_join("meta.json"))
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed as Dictionary if parsed is Dictionary else {}


# --- Escritura ---

## Guarda la caché del mundo (solo hace falta una vez por partida).
func write_world(save_name: String, world: Dictionary) -> Error:
	return _write_bin(get_save_dir(save_name).path_join("world.bin"), world)


func write_state(save_name: String, meta: Dictionary, state: Dictionary, players: Dictionary) -> Error:
	var dir: String = get_save_dir(save_name)
	DirAccess.make_dir_recursive_absolute(dir.path_join("players"))
	meta["save_version"] = SAVE_VERSION
	meta["saved_at"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()
	var err: Error = _write_bin(dir.path_join("state.bin"), {"save_version": SAVE_VERSION, "state": state})
	if err != OK:
		return err
	for player_id: String in players:
		err = _write_bin(dir.path_join("players").path_join(player_id.validate_filename() + ".bin"),
				{"save_version": SAVE_VERSION, "player": players[player_id]})
		if err != OK:
			return err
	return OK


func _write_bin(path: String, value: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# Primero a un temporal y luego se renombra: un corte a mitad no deja la partida rota.
	var tmp: String = path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(var_to_bytes(value))
	file.close()
	return DirAccess.rename_absolute(tmp, path)


# --- Lectura ---

func read_world(save_name: String) -> Dictionary:
	return _read_bin(get_save_dir(save_name).path_join("world.bin"))


## Estado dinámico ya migrado a la versión actual ({} si no existe).
func read_state(save_name: String) -> Dictionary:
	var wrapper: Dictionary = _read_bin(get_save_dir(save_name).path_join("state.bin"))
	if wrapper.is_empty():
		return {}
	return migrate(wrapper.get("state", {}) as Dictionary, int(wrapper.get("save_version", 0)))


func read_player(save_name: String, player_id: String) -> Dictionary:
	var wrapper: Dictionary = _read_bin(get_save_dir(save_name).path_join("players").path_join(player_id.validate_filename() + ".bin"))
	return wrapper.get("player", {}) as Dictionary


func _read_bin(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
	return value as Dictionary if value is Dictionary else {}


## Aplica en orden las migraciones desde `from_version` hasta SAVE_VERSION.
func migrate(state: Dictionary, from_version: int) -> Dictionary:
	var version: int = from_version
	while version < SAVE_VERSION:
		if not migrations.has(version):
			push_error("Partida: no hay migración desde la versión %d" % version)
			return state
		state = migrations[version].call(state)
		version += 1
	return state


func delete_save(save_name: String) -> void:
	var dir: String = get_save_dir(save_name)
	for sub: String in ["players", ""]:
		var path: String = dir.path_join(sub)
		var access := DirAccess.open(path)
		if access != null:
			for file: String in access.get_files():
				access.remove(file)
	DirAccess.remove_absolute(dir.path_join("players"))
	DirAccess.remove_absolute(dir)
