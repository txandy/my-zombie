class_name TargetDummy
extends StaticBody3D
## Dummy de pruebas de combate: hitboxes por zona, armadura opcional y reaparición.
## Cada zona se colorea según su vida (verde → rojo) y todo el dummy se oscurece al morir.

@export var armor_set: Array[ArmorDefinition] = []
@export var respawn_time_s: float = 3.0

@onready var health: HealthComponent = $Health
@onready var armor: ArmorComponent = $Armor
@onready var receiver: DamageReceiver = $DamageReceiver

var _materials: Dictionary[BodyZones.Zone, StandardMaterial3D] = {}


func _ready() -> void:
	collision_layer = PhysicsLayers.CHARACTERS
	armor.starting_armor = armor_set
	armor.reset()
	for hitbox: Node in $Hitboxes.get_children():
		var zone: BodyZones.Zone = (hitbox as Hitbox).zone
		var mesh: MeshInstance3D = hitbox.get_node("Mesh") as MeshInstance3D
		var material := StandardMaterial3D.new()
		mesh.material_override = material
		_materials[zone] = material
	health.zone_damaged.connect(func(_zone: BodyZones.Zone, _amount: float) -> void: _refresh())
	health.died.connect(_on_died)
	_refresh()


func _refresh() -> void:
	for zone: BodyZones.Zone in _materials:
		var ratio: float = health.hp(zone) / health.profile.max_hp(zone)
		var color: Color = Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.75, 0.35), ratio)
		if health.is_dead:
			color = color.darkened(0.6)
		_materials[zone].albedo_color = color


func _on_died(_zone: BodyZones.Zone) -> void:
	_refresh()
	await get_tree().create_timer(respawn_time_s).timeout
	health.reset()
	armor.reset()
	_refresh()
