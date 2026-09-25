class_name ArmorDefinition
extends Resource
## Pieza de armadura: casco o chaleco (GDD §6). Valores en /data/combat/armor/*.tres.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1, 6) var armor_class: int = 1
@export var max_durability: float = 0.0
## Zonas que protege.
@export var protected_zones: Array[BodyZones.Zone] = []
## Fracción del daño de la bala que llega a la zona cuando la armadura la detiene (daño romo).
@export var blunt_damage_factor: float = 0.0
## Fracción del daño que llega a la zona cuando la bala la atraviesa.
@export var penetrated_damage_factor: float = 1.0
## Durabilidad perdida por punto de penetración de la bala que impacta.
@export var durability_loss_factor: float = 0.0
