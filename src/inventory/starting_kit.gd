class_name StartingKit
extends Resource
## Equipo con el que aparece un personaje. Valores en /data/inventory/kits/*.tres.
## Primero se equipa (así el rig y la mochila aportan espacio) y luego se guarda el resto.

@export var entries: Array[KitEntry] = []
