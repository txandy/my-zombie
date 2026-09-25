class_name Hitbox
extends Area3D
## Zona de daño de un personaje (capa "hitboxes"). La registra su DamageReceiver.

@export var zone: BodyZones.Zone = BodyZones.Zone.THORAX

var receiver: DamageReceiver


func _ready() -> void:
	collision_layer = PhysicsLayers.HITBOXES
	collision_mask = 0
	monitoring = false
	monitorable = false
