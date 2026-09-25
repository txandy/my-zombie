extends Node
## Estado global de la sesión (autoload `GameState`).
##
## Solo el host modifica el estado. La replicación a clientes llega en M7 (GDD §12):
## los clientes recibirán la seed y regenerarán el mundo localmente.

var world_seed: int = 0
var is_session_active: bool = false


## Inicia una sesión con `new_world_seed`. Solo el host puede hacerlo.
func start_session(new_world_seed: int) -> bool:
	if not multiplayer.is_server():
		push_error("GameState.start_session: solo el host puede iniciar la sesión")
		return false
	world_seed = new_world_seed
	is_session_active = true
	EventBus.session_started.emit(world_seed)
	return true


## Termina la sesión actual.
func end_session() -> void:
	if not is_session_active:
		return
	is_session_active = false
	EventBus.session_ended.emit()


## Seed aleatoria para una partida nueva cuando el jugador no introduce una.
## No es generación del mundo: el mundo solo usa SeedUtil a partir de esta seed.
static func random_world_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Combina dos valores de 32 bits en un int64 con signo.
	return SeedUtil.fnv1a_64(PackedInt32Array([rng.randi(), rng.randi()]).to_byte_array())
