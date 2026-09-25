class_name DamageReceiver
extends Node
## Punto de entrada del daño de un personaje: une sus hitboxes, su armadura y su salud.
## Registra como propias todas las Hitbox que cuelgan de `hitboxes_root`.
## Solo el host aplica daño (AGENTS.md §1.1).

## Se emite en el host tras aplicar un impacto (para feedback: hitmarkers, HUD, IA).
signal hit_received(zone: BodyZones.Zone, result: DamageResolver.HitResult, source: Node)

@export var health: HealthComponent
## Opcional: sin armadura, todas las zonas reciben el daño completo.
@export var armor: ArmorComponent
@export var hitboxes_root: Node
@export var rules: CombatRules

var _hitboxes: Array[Hitbox] = []


func _ready() -> void:
	_collect_hitboxes(hitboxes_root)


func _collect_hitboxes(node: Node) -> void:
	for child: Node in node.get_children():
		var hitbox := child as Hitbox
		if hitbox != null:
			hitbox.receiver = self
			_hitboxes.append(hitbox)
		_collect_hitboxes(child)


## RIDs de las hitboxes propias (para que las balas del propio personaje no le den).
func hitbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for hitbox: Hitbox in _hitboxes:
		rids.append(hitbox.get_rid())
	return rids


func receive_bullet(zone: BodyZones.Zone, ammo: AmmoDefinition, source: Node,
		rng: RandomNumberGenerator) -> void:
	if not multiplayer.is_server() or health.is_dead:
		return
	var piece: ArmorInstance = armor.piece_for(zone) if armor != null else null
	var result: DamageResolver.HitResult = DamageResolver.resolve_bullet(ammo, piece, rules, rng)
	if piece != null:
		piece.durability -= result.durability_loss
	health.apply_damage(zone, result.damage, rng)
	hit_received.emit(zone, result, source)


## Cuerpo a cuerpo: la armadura de la zona reduce el golpe como daño romo y no se desgasta.
## 🔶 Regla provisional: el GDD no define la interacción melee-armadura.
func receive_melee(zone: BodyZones.Zone, damage: float, source: Node,
		rng: RandomNumberGenerator) -> void:
	if not multiplayer.is_server() or health.is_dead:
		return
	var result := DamageResolver.HitResult.new()
	var piece: ArmorInstance = armor.piece_for(zone) if armor != null else null
	result.armor_hit = piece != null
	result.penetrated = piece == null
	result.damage = damage * (piece.definition.blunt_damage_factor if piece != null else 1.0)
	health.apply_damage(zone, result.damage, rng)
	hit_received.emit(zone, result, source)
