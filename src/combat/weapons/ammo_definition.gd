class_name AmmoDefinition
extends Resource
## Tipo de munición (GDD §6). Valores en /data/combat/ammo/*.tres.

@export var id: StringName = &""
@export var display_name: String = ""
## Calibre; un arma solo acepta munición de su calibre.
@export var caliber: StringName = &""
## Daño base a la zona impactada sin armadura.
@export var damage: float = 0.0
## Penetración frente a armadura (escala 0-70; una clase de armadura equivale a clase × 10).
@export var penetration: float = 0.0
## Velocidad en boca (m/s).
@export var muzzle_velocity_mps: float = 0.0
## Proyectiles por disparo (1 salvo perdigones).
@export var projectile_count: int = 1
