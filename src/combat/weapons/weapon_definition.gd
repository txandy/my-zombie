class_name WeaponDefinition
extends Resource
## Arma de fuego o cuerpo a cuerpo (GDD §6). Valores en /data/combat/weapons/*.tres.
## Jugador y NPCs usan exactamente estas definiciones (AGENTS.md §1.5).

enum Kind { FIREARM, MELEE }
enum Slot { PRIMARY, SECONDARY, PISTOL, MELEE }
enum FireMode { SEMI, AUTO }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.FIREARM
@export var slot: Slot = Slot.PRIMARY

@export_group("Arma de fuego")
@export var fire_mode: FireMode = FireMode.SEMI
@export var rounds_per_minute: float = 0.0
@export var caliber: StringName = &""
@export var magazine_size: int = 0
@export var reload_time_s: float = 0.0
@export var default_ammo: AmmoDefinition
## Dispersión mecánica apuntando, en MOA.
@export var spread_moa: float = 0.0
## Multiplicador de la dispersión disparando desde la cadera.
@export var hip_spread_multiplier: float = 1.0
## Retroceso por disparo (grados) y velocidad de recuperación (fracción por segundo).
@export var recoil_vertical_deg: float = 0.0
@export var recoil_horizontal_deg: float = 0.0
@export var recoil_recovery: float = 0.0
## Radio (m) al que la IA oye el disparo (GDD §11.2).
@export var shot_sound_radius_m: float = 0.0

@export_group("Cuerpo a cuerpo")
@export var melee_damage: float = 0.0
@export var melee_range_m: float = 0.0
@export var melee_interval_s: float = 0.0


## Segundos entre disparos.
func fire_interval_s() -> float:
	return 60.0 / rounds_per_minute
