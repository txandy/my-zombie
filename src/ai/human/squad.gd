class_name Squad
extends Node3D
## Escuadra de NPCs (GDD §11.2): sus miembros son los HumanNPC hijos. Hace de
## "blackboard de escuadra": comparte contactos y reparte papeles en combate
## (uno suprime mientras otro flanquea).

enum Role { NONE, SUPPRESS, FLANK }

## Último contacto compartido por la escuadra.
var contact_position: Vector3
var contact_target: Node3D
var has_contact: bool = false

var _roles: Dictionary[HumanNPC, Role] = {}


func _ready() -> void:
	for member: HumanNPC in members():
		member.squad = self


func members() -> Array[HumanNPC]:
	var result: Array[HumanNPC] = []
	for child: Node in get_children():
		var npc := child as HumanNPC
		if npc != null and not npc.is_dead:
			result.append(npc)
	return result


## Un miembro ha visto a un objetivo: los demás lo saben (con algo menos de confianza).
func share_contact(from: HumanNPC, memory: Perception.Memory) -> void:
	contact_position = memory.last_known_position
	contact_target = memory.target
	has_contact = true
	for member: HumanNPC in members():
		if member == from:
			continue
		var theirs: Perception.Memory = member.perception.memory
		if theirs.confidence < 0.8:
			theirs.target = memory.target
			theirs.last_known_position = memory.last_known_position
			theirs.last_known_velocity = memory.last_known_velocity
			theirs.confidence = 0.8


## Papel de un miembro en el combate actual. El primero en pedirlo suprime; si la escuadra
## tiene más de un miembro vivo, el más agresivo de los demás flanquea.
func role_of(member: HumanNPC) -> Role:
	_prune_roles()
	if _roles.has(member):
		return _roles[member]
	var role: Role = Role.SUPPRESS
	if _roles.values().has(Role.SUPPRESS) and not _roles.values().has(Role.FLANK) \
			and member.profile.aggression >= 0.5:
		role = Role.FLANK
	_roles[member] = role
	return role


func release_role(member: HumanNPC) -> void:
	_roles.erase(member)


func _prune_roles() -> void:
	for member: HumanNPC in _roles.keys():
		if not is_instance_valid(member) or member.is_dead:
			_roles.erase(member)
