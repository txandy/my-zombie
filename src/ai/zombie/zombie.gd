class_name Zombie
extends CharacterBody3D
## Zombi (GDD §11.1). IA barata a propósito: máquina de estados simple en código,
## percepción simplificada a intervalos (oído, olfato y vista corta) y movimiento
## directo hacia el objetivo (sin comportamiento táctico). Solo corre en el host.
## Usa el mismo sistema de daño por zonas que humanos y jugadores (hitboxes, salud).

signal died()

enum State { WANDER, INVESTIGATE, CHASE, ATTACK, DEAD }

@export var profile: ZombieProfile
## Segundos que el cadáver permanece antes de desaparecer.
@export var corpse_time_s: float = 20.0

## Estado (lo decide el host y se replica; al morir se ve el cadáver en todos los peers).
var state: State = State.WANDER:
	set(value):
		state = value
		if value == State.DEAD and is_node_ready():
			_show_corpse()
var target: Node3D
## Punto de interés (sonido oído, objetivo de horda).
var goal: Vector3
var home: Vector3
## Zombi de horda: conoce siempre la posición del objetivo (GDD §4.5).
var horde_target: Node3D

var _perception_timer: float = 0.0
var _attack_timer: float = 0.0
var _unseen_s: float = 0.0
var _wander_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health: HealthComponent = $Health
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"zombie")
	NetSync.add(self, [":position", ":rotation", ":state"], 1, true, 0.05)
	collision_layer = PhysicsLayers.CHARACTERS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CHARACTERS
	home = global_position
	goal = global_position
	health.died.connect(_on_died)
	EventBus.sound_emitted.connect(_on_sound)
	($DamageReceiver as DamageReceiver).hit_received.connect(_on_hit)
	_perception_timer = Ballistics.rng.randf() * profile.perception_interval_s


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = profile.perception_interval_s
		_perceive(profile.perception_interval_s)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	match state:
		State.WANDER:
			_wander(delta)
		State.INVESTIGATE:
			_move_towards(goal, profile.wander_speed * 1.5, delta)
			if _flat(goal - global_position).length() < 1.5:
				state = State.WANDER
		State.CHASE, State.ATTACK:
			_chase(delta)
	move_and_slide()


func chase_speed() -> float:
	var speed: float = profile.chase_speed_night if GameState.is_night else profile.chase_speed_day
	return speed * health.movement_multiplier()


# --- Percepción barata ---

func _perceive(interval: float) -> void:
	if horde_target != null and is_instance_valid(horde_target):
		target = horde_target
		state = State.CHASE if state != State.ATTACK else state
		return
	var best: Node3D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Node3D
		if Perception._is_dead(player):
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance and (distance <= profile.smell_radius_m or _can_see(player, distance)):
			best = player
			best_distance = distance
	if best != null:
		target = best
		_unseen_s = 0.0
		if state != State.ATTACK:
			state = State.CHASE
	elif state == State.CHASE:
		_unseen_s += interval
		if _unseen_s >= profile.give_up_s:
			state = State.INVESTIGATE
			goal = target.global_position if is_instance_valid(target) else home


func _can_see(player: Node3D, distance: float) -> bool:
	if distance > profile.sight_range_m:
		return false
	var to_player: Vector3 = player.global_position - global_position
	if rad_to_deg((-global_basis.z).angle_to(_flat(to_player))) > profile.sight_fov_deg * 0.5:
		return false
	var eye: Vector3 = global_position + Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3.UP * 1.3,
			PhysicsLayers.WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_sound(position: Vector3, radius_m: float, _kind: StringName, source: Node) -> void:
	if not multiplayer.is_server():
		return
	if state == State.DEAD or state == State.CHASE or state == State.ATTACK:
		return
	if source != null and source.is_in_group(&"zombie"):
		return
	if position.distance_to(global_position) <= radius_m * profile.hearing_multiplier:
		goal = position
		state = State.INVESTIGATE


# --- Movimiento y ataque ---

func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = Ballistics.rng.randf_range(3.0, 8.0)
		var offset := Vector3(Ballistics.rng.randf_range(-1, 1), 0, Ballistics.rng.randf_range(-1, 1)).normalized()
		goal = home + offset * Ballistics.rng.randf_range(2.0, 10.0)
	if _flat(goal - global_position).length() > 1.0:
		_move_towards(goal, profile.wander_speed, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or Perception._is_dead(target):
		state = State.WANDER
		target = null
		return
	var to_target: Vector3 = _flat(target.global_position - global_position)
	if to_target.length() <= profile.attack_range_m:
		state = State.ATTACK
		velocity.x = 0.0
		velocity.z = 0.0
		_face(target.global_position, delta)
		if _attack_timer <= 0.0:
			_attack(target)
	else:
		state = State.CHASE
		_move_towards(target.global_position, chase_speed(), delta)
		_attack_blocking_structure()


# Si una pieza de construcción le corta el paso, la golpea (GDD §10: los zombis atacan la base).
func _attack_blocking_structure() -> void:
	if _attack_timer > 0.0:
		return
	for i: int in get_slide_collision_count():
		var piece := get_slide_collision(i).get_collider() as BuildingPieceNode
		if piece != null:
			_attack_timer = profile.attack_interval_s
			piece.receive_structure_damage(profile.structure_damage)
			EventBus.sound_emitted.emit(global_position, 25.0, &"zombie_attack", self)
			return


func _attack(victim: Node3D) -> void:
	_attack_timer = profile.attack_interval_s
	var receiver := victim.get_node_or_null(^"DamageReceiver") as DamageReceiver
	if receiver == null:
		return
	# Muerde el torso o un brazo (lo que tiene delante).
	var zones: Array[BodyZones.Zone] = [BodyZones.Zone.THORAX, BodyZones.Zone.STOMACH,
			BodyZones.Zone.LEFT_ARM, BodyZones.Zone.RIGHT_ARM]
	var zone: BodyZones.Zone = zones[Ballistics.rng.randi_range(0, zones.size() - 1)]
	var victim_health: HealthComponent = receiver.health
	var before: float = victim_health.hp(zone)
	receiver.receive_melee(zone, profile.attack_damage, self, Ballistics.rng)
	# Solo infecta si la mordedura ha llegado a hacer daño (la armadura puede frenarla del todo).
	if victim_health.hp(zone) < before and Ballistics.rng.randf() < profile.infection_chance:
		victim_health.infect()
	EventBus.sound_emitted.emit(global_position, 15.0, &"zombie_attack", self)


func _move_towards(point: Vector3, speed: float, delta: float) -> void:
	var direction: Vector3 = _flat(point - global_position)
	if direction.length() < 0.05:
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(point, delta)


func _face(point: Vector3, delta: float) -> void:
	var to_point: Vector3 = _flat(point - global_position)
	if to_point.length() < 0.05:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-to_point.x, -to_point.z), deg_to_rad(profile.turn_speed_deg) * delta)


# Al recibir un golpe o un disparo va a por quien se lo ha hecho.
func _on_hit(_zone: BodyZones.Zone, _result: DamageResolver.HitResult, source: Node) -> void:
	if not multiplayer.is_server():
		return
	var attacker := source as Node3D
	if attacker != null and state != State.DEAD and not attacker.is_in_group(&"zombie"):
		target = attacker
		_unseen_s = 0.0
		state = State.CHASE


func _on_died(_zone: BodyZones.Zone) -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	died.emit()
	await get_tree().create_timer(corpse_time_s).timeout
	queue_free()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _show_corpse() -> void:
	collision_layer = 0
	_visual.rotation.x = -PI * 0.5
	_visual.position.y = 0.2
