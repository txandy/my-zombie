class_name HumanBrain
extends Node
## Cerebro de un NPC humano (GDD §11.2): máquina de estados LimboAI de alto nivel
## (Patrulla -> Alerta -> Combate -> Búsqueda -> Retirada) con un behavior tree en Combate.
## La actualiza el propio NPC en modo manual, lo que permite el LOD de IA.

const PatrolState := preload("res://src/ai/human/brain/patrol_state.gd")
const AlertState := preload("res://src/ai/human/brain/alert_state.gd")
const SearchState := preload("res://src/ai/human/brain/search_state.gd")
const RetreatState := preload("res://src/ai/human/brain/retreat_state.gd")
## Evento que emite un estado al terminar (LimboState.EVENT_FINISHED es de instancia).
const FINISHED: StringName = &"finished"

var hsm: LimboHSM
var patrol: LimboState
var alert: LimboState
var combat: BTState
var search: LimboState
var retreat: LimboState


## Monta la máquina de estados para `npc`.
func setup(npc: HumanNPC) -> void:
	hsm = LimboHSM.new()
	hsm.name = "HSM"
	hsm.update_mode = LimboHSM.MANUAL
	add_child(hsm)
	patrol = _add_state(PatrolState.new(), "Patrol")
	alert = _add_state(AlertState.new(), "Alert")
	search = _add_state(SearchState.new(), "Search")
	retreat = _add_state(RetreatState.new(), "Retreat")
	combat = BTState.new()
	combat.name = "Combat"
	combat.behavior_tree = CombatTree.build()
	# Creado por código no tiene dueño en la escena: hay que indicarle la raíz.
	combat.set_scene_root_hint(npc)
	hsm.add_child(combat)
	for state: LimboState in [patrol, alert, search]:
		hsm.add_transition(state, combat, &"spotted")
		hsm.add_transition(state, combat, &"attacked")
	hsm.add_transition(patrol, alert, &"noise")
	hsm.add_transition(alert, patrol, FINISHED)
	hsm.add_transition(combat, search, &"target_lost")
	hsm.add_transition(combat, retreat, &"retreat")
	hsm.add_transition(retreat, combat, FINISHED)
	hsm.add_transition(search, patrol, FINISHED)
	hsm.initial_state = patrol
	hsm.initialize(npc)
	hsm.set_active(true)
	npc.perception.target_spotted.connect(func(_t: Node3D) -> void: dispatch(&"spotted"))
	npc.perception.sound_heard.connect(func(_p: Vector3, _k: StringName) -> void: dispatch(&"noise"))
	(npc.get_node(^"DamageReceiver") as DamageReceiver).hit_received.connect(_on_hit.bind(npc))


func _add_state(state: LimboState, state_name: String) -> LimboState:
	state.name = state_name
	hsm.add_child(state)
	return state


func update(delta: float) -> void:
	if hsm != null and hsm.is_active():
		hsm.update(delta)


func dispatch(event: StringName) -> void:
	if hsm != null and hsm.is_active():
		hsm.dispatch(event)


func state_name() -> StringName:
	var state: LimboState = hsm.get_active_state() if hsm != null else null
	return StringName(state.name) if state != null else &""


func stop() -> void:
	if hsm != null:
		hsm.set_active(false)


# Si le disparan, sabe de dónde viene el fuego aunque no haya visto al tirador.
func _on_hit(_zone: BodyZones.Zone, _result: DamageResolver.HitResult, source: Node, npc: HumanNPC) -> void:
	var shooter := source as Node3D
	if shooter == null or npc.is_dead:
		return
	var memory: Perception.Memory = npc.perception.memory
	if memory.confidence < 0.7:
		memory.target = shooter
		memory.last_known_position = shooter.global_position
		memory.confidence = 0.7
	if state_name() != &"Combat":
		npc.aim_model.on_target_acquired(Ballistics.rng)
	dispatch(&"attacked")
