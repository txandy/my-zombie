class_name CombatRules
extends Resource
## Reglas globales del combate. Valores en /data/combat/combat_rules.tres (ADR 0003).

@export_group("Penetración")
## Anchura de la rampa de probabilidad: con penetración = valor de la armadura la
## probabilidad es 0.5; a ±spread llega a 1 / 0.
@export var penetration_spread: float = 0.0
## Eficacia de la armadura con durabilidad 0, como fracción de su clase (0-1).
@export var min_armor_effectiveness: float = 0.0
