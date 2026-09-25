extends Node
## Simulación de proyectiles (autoload `Ballistics`). GDD §6.
##
## Cada bala avanza por tick de física con su velocidad y la gravedad, y se comprueba
## el segmento recorrido con un raycast contra el mundo y las hitboxes. Solo el host
## simula e impacta; jugador y NPCs disparan por aquí (AGENTS.md §1.1 y §1.5).
## La penetración de materiales queda para una fase posterior.

## Se emite al disparar (host). Para trazadoras, sonido y percepción de la IA.
signal projectile_fired(origin: Vector3, velocity: Vector3, source: Node)
## Se emite al impactar (host). `hitbox` es null si ha dado en el mundo.
signal projectile_impacted(position: Vector3, normal: Vector3, hitbox: Hitbox, source: Node)

## Tiempo máximo de vuelo de una bala.
const MAX_LIFETIME_S: float = 4.0


class Projectile:
	extends RefCounted
	var position: Vector3
	var velocity: Vector3
	var ammo: AmmoDefinition
	var source: Node
	var exclude: Array[RID] = []
	var age_s: float = 0.0


## RNG de combate del host (tiradas de penetración y estados). Nunca el global.
var rng := RandomNumberGenerator.new()

var _projectiles: Array[Projectile] = []
var _gravity: Vector3 = Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))


func _ready() -> void:
	rng.randomize()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and not _projectiles.is_empty():
		step(delta)


## Dispara una bala. `exclude` son RIDs que la bala ignora (el cuerpo y las hitboxes del tirador).
func fire(origin: Vector3, direction: Vector3, ammo: AmmoDefinition, source: Node,
		exclude: Array[RID] = []) -> void:
	if not multiplayer.is_server():
		return
	var p := Projectile.new()
	p.position = origin
	p.velocity = direction.normalized() * ammo.muzzle_velocity_mps
	p.ammo = ammo
	p.source = source
	p.exclude = exclude
	_projectiles.append(p)
	projectile_fired.emit(origin, p.velocity, source)


func active_count() -> int:
	return _projectiles.size()


func clear() -> void:
	_projectiles.clear()


## Avanza todas las balas un tick. Público para los tests.
func step(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var alive: Array[Projectile] = []
	for p: Projectile in _projectiles:
		if not _advance(p, delta, space):
			alive.append(p)
	_projectiles = alive


# Mueve la bala un tick. Devuelve true si ha terminado (impacto o fin de vida).
func _advance(p: Projectile, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	var next: Vector3 = p.position + p.velocity * delta + _gravity * (0.5 * delta * delta)
	var query := PhysicsRayQueryParameters3D.create(p.position, next, PhysicsLayers.PROJECTILE_MASK, p.exclude)
	query.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		_impact(p, hit)
		return true
	p.position = next
	p.velocity += _gravity * delta
	p.age_s += delta
	return p.age_s >= MAX_LIFETIME_S


func _impact(p: Projectile, hit: Dictionary) -> void:
	var hitbox := hit.collider as Hitbox
	if hitbox != null and hitbox.receiver != null:
		hitbox.receiver.receive_bullet(hitbox.zone, p.ammo, p.source, rng)
	projectile_impacted.emit(hit.position as Vector3, hit.normal as Vector3, hitbox, p.source)
