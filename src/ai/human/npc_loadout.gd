class_name NPCLoadout
extends Resource
## Equipo de un arquetipo de NPC, generado con tablas de loot (GDD §8): lo que lleva
## equipado es lo que usa en combate y lo que suelta al morir.
## Cada slot usa una tabla (una tirada; empty_chance = probabilidad de no llevar nada).

@export var primary: LootTable
@export var pistol: LootTable
@export var melee: LootTable
@export var helmet: LootTable
@export var torso: LootTable
@export var backpack: LootTable
## Objetos guardados (medicinas, chatarra...).
@export var storage: LootTable
## Cargadores de repuesto garantizados para cada arma de fuego que lleve.
@export var spare_magazines: int = 2
