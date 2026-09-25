class_name CoverFinder
## Elige cobertura frente a una amenaza con utility scoring (GDD §11.2).
## Candidatos: puntos de cobertura de los POIs y huecos detrás de troncos y rocas.
## Cada candidato se puntúa por protección (raycast desde la amenaza), si permite
## asomarse, distancia al NPC, distancia de combate preferida y, si flanquea, ángulo.


class Cover:
	extends RefCounted
	var position: Vector3
	## Hay que agacharse para cubrirse (cobertura baja).
	var crouch: bool = true
	var score: float = -INF


const SEARCH_RADIUS_M: float = 30.0
const MAX_CANDIDATES: int = 16
const PREFERRED_RANGE_M: float = 30.0
## Distancia detrás del obstáculo donde se coloca el NPC.
const STANDOFF_M: float = 0.7


## Mejor cobertura para `npc` frente a `threat`, o null. `flank_from` (opcional): posición
## de la escuadra; si se da, se premian coberturas con un ángulo distinto hacia la amenaza.
## `away`: prioriza alejarse de la amenaza (retirada).
static func find(npc: Node3D, threat: Vector3, flank_from: Variant = null, away: bool = false) -> Cover:
	var best: Cover = null
	for candidate: Cover in _candidates(npc, threat):
		candidate.score = _score(npc, candidate, threat, flank_from, away)
		if best == null or candidate.score > best.score:
			best = candidate
	return best if best != null and best.score > 0.0 else null


static func _candidates(npc: Node3D, threat: Vector3) -> Array[Cover]:
	var result: Array[Cover] = []
	var origin: Vector3 = npc.global_position
	for node: Node in npc.get_tree().get_nodes_in_group(&"cover_point"):
		var point := node as CoverPoint
		if point.global_position.distance_to(origin) <= SEARCH_RADIUS_M:
			var cover := Cover.new()
			cover.position = point.global_position
			cover.crouch = point.low
			result.append(cover)
	var registry := npc.get_tree().get_first_node_in_group(&"cover_registry") as CoverRegistry
	if registry != null:
		for obstacle: Dictionary in registry.obstacles_near(origin, SEARCH_RADIUS_M):
			var at: Vector3 = obstacle.position
			var away_from_threat: Vector3 = Vector3(at.x - threat.x, 0, at.z - threat.z).normalized()
			var cover := Cover.new()
			cover.position = at + away_from_threat * (float(obstacle.radius) + STANDOFF_M)
			cover.position.y = origin.y
			cover.crouch = float(obstacle.height) < 1.5
			result.append(cover)
	result.sort_custom(func(a: Cover, b: Cover) -> bool:
		return a.position.distance_squared_to(origin) < b.position.distance_squared_to(origin))
	return result.slice(0, MAX_CANDIDATES)


static func _score(npc: Node3D, cover: Cover, threat: Vector3, flank_from: Variant, away: bool) -> float:
	var space: PhysicsDirectSpaceState3D = npc.get_world_3d().direct_space_state
	var threat_eye: Vector3 = threat + Vector3.UP * 1.5
	var hide_height: float = 0.9 if cover.crouch else 1.5
	var protected: bool = _blocked(space, threat_eye, cover.position + Vector3.UP * hide_height, npc)
	if not protected:
		return -1.0
	var threat_distance: float = cover.position.distance_to(threat)
	var score: float = 3.0
	# Poder asomarse: de pie (cobertura baja) o de lado (alta).
	var peek: Vector3 = cover.position + Vector3.UP * 1.6
	if not cover.crouch:
		peek += (threat - cover.position).cross(Vector3.UP).normalized() * 0.6
	if not _blocked(space, peek, threat_eye, npc):
		score += 1.5
	score -= npc.global_position.distance_to(cover.position) * 0.05
	if away:
		score += threat_distance * 0.05
	else:
		score -= absf(threat_distance - PREFERRED_RANGE_M) * 0.02
	if flank_from != null:
		var squad_dir: Vector3 = ((flank_from as Vector3) - threat).normalized()
		var my_dir: Vector3 = (cover.position - threat).normalized()
		score += clampf(rad_to_deg(squad_dir.angle_to(my_dir)) / 90.0, 0.0, 1.0) * 2.0
	return score


static func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, npc: Node3D) -> bool:
	var exclude: Array[RID] = []
	if npc is CollisionObject3D:
		exclude.append((npc as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD, exclude)
	return not space.intersect_ray(query).is_empty()
