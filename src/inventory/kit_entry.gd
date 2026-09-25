class_name KitEntry
extends Resource
## Una línea de un kit inicial: objeto, cantidad y slot donde equiparlo (-1 = guardar).

@export var item: ItemDefinition
@export var quantity: int = 1
## Inventory.Slot o -1 para guardarlo en bolsillos/rig/mochila.
@export var slot: int = -1
