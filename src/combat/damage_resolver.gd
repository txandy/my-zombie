class_name DamageResolver
## Resuelve el impacto de una bala en una zona, con o sin armadura (GDD §6, ADR 0003).
## Funciones puras: no tocan la salud. Quien aplica el resultado es el host.


class HitResult:
	extends RefCounted
	## Daño que llega a la zona.
	var damage: float = 0.0
	## True si había armadura en la zona.
	var armor_hit: bool = false
	## True si la bala atravesó la armadura (o no había).
	var penetrated: bool = true
	## Probabilidad de penetración usada en la tirada (1 sin armadura).
	var penetration_chance: float = 1.0
	## Durabilidad que pierde la armadura.
	var durability_loss: float = 0.0


## Valor efectivo de la armadura (clase × 10), reducido según su durabilidad.
static func armor_rating(armor: ArmorInstance, rules: CombatRules) -> float:
	var effectiveness: float = lerpf(rules.min_armor_effectiveness, 1.0, armor.durability_ratio())
	return armor.definition.armor_class * 10.0 * effectiveness


## Probabilidad (0-1) de que una bala con `penetration` atraviese la armadura.
static func penetration_chance(penetration: float, armor: ArmorInstance, rules: CombatRules) -> float:
	var margin: float = penetration - armor_rating(armor, rules)
	return clampf(0.5 + margin / (2.0 * rules.penetration_spread), 0.0, 1.0)


## Resuelve un impacto. `armor` puede ser null (zona sin proteger).
## Consume siempre una tirada del RNG para que la secuencia no dependa de la armadura.
static func resolve_bullet(ammo: AmmoDefinition, armor: ArmorInstance, rules: CombatRules,
		rng: RandomNumberGenerator) -> HitResult:
	var roll: float = rng.randf()
	var result := HitResult.new()
	if armor == null:
		result.damage = ammo.damage
		return result
	result.armor_hit = true
	result.penetration_chance = penetration_chance(ammo.penetration, armor, rules)
	result.penetrated = roll < result.penetration_chance
	var factor: float = (armor.definition.penetrated_damage_factor if result.penetrated
			else armor.definition.blunt_damage_factor)
	result.damage = ammo.damage * factor
	result.durability_loss = minf(ammo.penetration * armor.definition.durability_loss_factor, armor.durability)
	return result
