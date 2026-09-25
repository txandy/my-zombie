extends Control
## HUD de combate mínimo (GDD §14): punto de mira, arma y munición, salud por zonas
## con estados, y marcador de impacto. Solo lee estado y escucha señales; nunca lo modifica.

@export var health: HealthComponent
@export var weapons: WeaponHolder
@export var receiver: DamageReceiver
@export var interactor: Interactor
@export var survival: SurvivalComponent
## Segundos que se muestra la salud tras recibir daño (GDD §14: visible al recibir daño).
@export var health_visible_s: float = 6.0

var _health_timer: float = 0.0
var _hitmarker_timer: float = 0.0
var _reload_timer: float = 0.0

@onready var _crosshair: Label = $Crosshair
@onready var _hitmarker: Label = $Hitmarker
@onready var _weapon_label: Label = $WeaponLabel
@onready var _health_label: Label = $HealthLabel
@onready var _status_label: Label = $StatusLabel
@onready var _prompt_label: Label = $PromptLabel
@onready var _stamina_bar: ProgressBar = $StaminaBar


func _ready() -> void:
	health.zone_damaged.connect(func(_z: BodyZones.Zone, _a: float) -> void: _health_timer = health_visible_s)
	health.status_changed.connect(func() -> void: _health_timer = health_visible_s)
	weapons.reload_started.connect(func(duration: float) -> void: _reload_timer = duration)
	Ballistics.projectile_impacted.connect(_on_impact)


func _on_impact(_position: Vector3, _normal: Vector3, hitbox: Hitbox, source: Node) -> void:
	if hitbox != null and source == weapons.get_parent() and hitbox.receiver != receiver:
		_hitmarker_timer = 0.15


func _process(delta: float) -> void:
	_health_timer = maxf(_health_timer - delta, 0.0)
	_hitmarker_timer = maxf(_hitmarker_timer - delta, 0.0)
	_reload_timer = maxf(_reload_timer - delta, 0.0)
	_hitmarker.visible = _hitmarker_timer > 0.0
	_crosshair.visible = not Input.is_action_pressed(&"aim")
	_weapon_label.text = _weapon_text()
	_health_label.visible = _health_timer > 0.0 or health.is_dead
	_health_label.text = _health_text()
	_status_label.text = _status_text()
	_stamina_bar.value = survival.stamina / survival.profile.max_stamina * 100.0
	_stamina_bar.visible = survival.stamina < survival.profile.max_stamina - 0.5
	if is_instance_valid(interactor.focused):
		_prompt_label.text = "[F] %s" % String(interactor.focused.call(&"interaction_text"))
	else:
		_prompt_label.text = ""


func _weapon_text() -> String:
	var weapon: WeaponDefinition = weapons.current()
	if weapon == null:
		return ""
	if weapon.kind == WeaponDefinition.Kind.MELEE:
		return weapon.display_name
	var state: String = "  RECARGANDO %.1fs" % _reload_timer if _reload_timer > 0.0 else ""
	var reserve: int = weapons.reserve_ammo()
	var reserve_text: String = " (+%d)" % reserve if reserve >= 0 else ""
	return "%s  %d/%d%s  %s%s" % [weapon.display_name, weapons.current_rounds(), weapon.magazine_size,
			reserve_text, weapons.loaded_ammo().display_name, state]


func _health_text() -> String:
	if health.is_dead:
		return "MUERTO"
	var lines: PackedStringArray = []
	for zone: BodyZones.Zone in BodyZones.ALL:
		var marks: String = ""
		match health.bleeding(zone):
			HealthComponent.Bleed.LIGHT:
				marks += " [sangrado]"
			HealthComponent.Bleed.HEAVY:
				marks += " [SANGRADO GRAVE]"
		if health.is_fractured(zone):
			marks += " [fractura]"
		lines.append("%-12s %3.0f / %.0f%s" % [BodyZones.display_name(zone), health.hp(zone),
				health.profile.max_hp(zone), marks])
	return "\n".join(lines)


func _status_text() -> String:
	var parts: PackedStringArray = []
	if health.has_pain():
		parts.append("DOLOR")
	if not health.can_sprint():
		parts.append("NO PUEDES ESPRINTAR")
	var critical: float = survival.profile.critical_level
	if survival.hunger < critical:
		parts.append("HAMBRE %.0f" % survival.hunger)
	if survival.thirst < critical:
		parts.append("SED %.0f" % survival.thirst)
	if survival.body_temp_c <= survival.profile.hypothermia_c:
		parts.append("HIPOTERMIA %.1f °C" % survival.body_temp_c)
	elif survival.body_temp_c < 36.0:
		parts.append("FRÍO %.1f °C" % survival.body_temp_c)
	elif survival.body_temp_c >= survival.profile.hyperthermia_c:
		parts.append("CALOR %.1f °C" % survival.body_temp_c)
	return "  ·  ".join(parts)
