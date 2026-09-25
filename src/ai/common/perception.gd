class_name Perception
extends Node
## Percepción de un NPC (GDD §11.2): vista, oído, memoria y supresión. Solo en el host.
##
## Vista: cono de visión y raycasts a las hitboxes del objetivo (cabeza, tórax, pelvis,
## extremidades). La visibilidad depende de la parte expuesta, la distancia, la postura,
## el movimiento y la luz, y la detección se acumula con el tiempo en lugar de ser
## instantánea. Las comprobaciones se hacen a intervalos, no cada frame (AGENTS.md §6).

signal target_spotted(target: Node3D)
signal sound_heard(position: Vector3, kind: StringName)


class Memory:
	extends RefCounted
	var target: Node3D
	var last_known_position: Vector3
	var last_known_velocity: Vector3
	## 1 = visto ahora mismo; baja a 0 en memory_duration_s.
	var confidence: float = 0.0


@export var profile: NPCCombatProfile
@export var rules: PerceptionRules
@export var body: CharacterBody3D
## Punto de vista (ojos). Su -Z es hacia donde mira.
@export var eye: Node3D
## Grupos de nodos que son objetivos (hostiles) para este NPC.
@export var target_groups: Array[StringName] = [&"player"]

var memory := Memory.new()
## Supresión actual (0-1).
var suppression: float = 0.0
## Medidor de detección por objetivo (0-1; 1 = detectado).
var detection: Dictionary[Node3D, float] = {}

var _visible_now: Dictionary[Node3D, bool] = {}
var _vision_timer: float = 0.0


func _ready() -> void:
	EventBus.sound_emitted.connect(_on_sound)
	Ballistics.projectile_fired.connect(_on_projectile_fired)
	_vision_timer = randf() * rules.vision_interval_s


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	suppression = maxf(suppression - rules.suppression_decay_per_s * delta, 0.0)
	if memory.target != null and not is_target_visible(memory.target):
		memory.confidence = maxf(memory.confidence - delta / profile.memory_duration_s, 0.0)
	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = rules.vision_interval_s
		update_vision(rules.vision_interval_s)


## Comprueba la visión de todos los objetivos. Público para los tests.
func update_vision(interval: float) -> void:
	for target: Node3D in candidates():
		var visibility: float = visibility_of(target)
		_visible_now[target] = visibility > 0.0
		var meter: float = detection.get(target, 0.0)
		if visibility > 0.0:
			meter += visibility * interval / profile.detection_time_s
		else:
			meter -= rules.detection_decay_per_s * interval
		meter = clampf(meter, 0.0, 1.0)
		var was_detected: bool = detection.get(target, 0.0) >= 1.0
		detection[target] = meter
		if meter >= 1.0 and visibility > 0.0:
			_remember_seen(target)
			if not was_detected:
				target_spotted.emit(target)


func candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for group: StringName in target_groups:
		for node: Node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if target != null and target != body and not _is_dead(target):
				result.append(target)
	return result


func is_target_visible(target: Node3D) -> bool:
	return _visible_now.get(target, false)


func is_detected(target: Node3D) -> bool:
	return detection.get(target, 0.0) >= 1.0


## Visibilidad (0-1) del objetivo desde los ojos de este NPC ahora mismo.
func visibility_of(target: Node3D) -> float:
	var to_target: Vector3 = target.global_position + Vector3.UP - eye.global_position
	var distance: float = to_target.length()
	if distance > profile.vision_range_m:
		return 0.0
	var forward: Vector3 = -eye.global_basis.z
	# A muy corta distancia se "nota" aunque esté fuera del cono.
	if distance > 3.0 and rad_to_deg(forward.angle_to(to_target)) > profile.vision_fov_deg * 0.5:
		return 0.0
	var exposure: float = exposure_of(target)
	if exposure <= 0.0:
		return 0.0
	var visibility: float = exposure * lerpf(1.0, rules.visibility_at_max_range, distance / profile.vision_range_m)
	visibility *= _posture_factor(target)
	if target is CharacterBody3D and (target as CharacterBody3D).velocity.length() > 1.0:
		visibility *= rules.moving_visibility
	visibility *= lerpf(rules.night_visibility, 1.0, GameState.ambient_light)
	return clampf(visibility, 0.0, 1.0)


## Fracción de las zonas del cuerpo del objetivo con línea de visión directa.
func exposure_of(target: Node3D) -> float:
	var points: Array[Vector3] = _body_points(target)
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var seen: int = 0
	for point: Vector3 in points:
		var query := PhysicsRayQueryParameters3D.create(eye.global_position, point, PhysicsLayers.WORLD, [body.get_rid()])
		if space.intersect_ray(query).is_empty():
			seen += 1
	return seen / float(points.size())


func _body_points(target: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var hitboxes: Node = target.get_node_or_null(^"Hitboxes")
	if hitboxes != null:
		for child: Node in hitboxes.get_children():
			points.append((child as Node3D).global_position)
	if points.is_empty():
		points.append(target.global_position + Vector3.UP)
	return points


func _posture_factor(target: Node3D) -> float:
	if not target.has_method(&"get_posture"):
		return 1.0
	match int(target.call(&"get_posture")):
		PostureComponent.Posture.CROUCHING:
			return rules.crouch_visibility
		PostureComponent.Posture.PRONE:
			return rules.prone_visibility
	return 1.0


func _remember_seen(target: Node3D) -> void:
	memory.target = target
	memory.last_known_position = target.global_position
	memory.last_known_velocity = (target as CharacterBody3D).velocity if target is CharacterBody3D else Vector3.ZERO
	memory.confidence = 1.0


func _on_sound(position: Vector3, radius_m: float, kind: StringName, source: Node) -> void:
	if not multiplayer.is_server() or source == body or not _is_hostile(source):
		return
	if eye.global_position.distance_to(position) > radius_m * profile.hearing_multiplier:
		return
	# Oír da una idea de la posición, con menos confianza que verla.
	if memory.confidence < 0.5:
		memory.target = source as Node3D
		memory.last_known_position = position
		memory.last_known_velocity = Vector3.ZERO
		memory.confidence = 0.5
	sound_heard.emit(position, kind)


func _on_projectile_fired(origin: Vector3, velocity: Vector3, source: Node) -> void:
	if not multiplayer.is_server() or source == body or not _is_hostile(source):
		return
	var direction: Vector3 = velocity.normalized()
	var to_me: Vector3 = eye.global_position - origin
	var along: float = to_me.dot(direction)
	if along <= 0.0 or along > 400.0:
		return
	if (to_me - direction * along).length() <= rules.suppression_radius_m:
		suppression = minf(suppression + rules.suppression_per_bullet, 1.0)


func _is_hostile(source: Node) -> bool:
	if source == null:
		return false
	for group: StringName in target_groups:
		if source.is_in_group(group):
			return true
	return false


static func _is_dead(target: Node) -> bool:
	var health := target.get_node_or_null(^"Health") as HealthComponent
	return health != null and health.is_dead
