class_name BodyZones
## Zonas del cuerpo para el daño localizado (GDD §5.1). Iguales para jugador y NPCs humanos.

enum Zone { HEAD, THORAX, STOMACH, LEFT_ARM, RIGHT_ARM, LEFT_LEG, RIGHT_LEG }

const COUNT: int = 7
const ALL: Array[Zone] = [Zone.HEAD, Zone.THORAX, Zone.STOMACH, Zone.LEFT_ARM,
		Zone.RIGHT_ARM, Zone.LEFT_LEG, Zone.RIGHT_LEG]


## Cabeza o tórax a 0 = muerte.
static func is_vital(zone: Zone) -> bool:
	return zone == Zone.HEAD or zone == Zone.THORAX


static func is_arm(zone: Zone) -> bool:
	return zone == Zone.LEFT_ARM or zone == Zone.RIGHT_ARM


static func is_leg(zone: Zone) -> bool:
	return zone == Zone.LEFT_LEG or zone == Zone.RIGHT_LEG


static func is_limb(zone: Zone) -> bool:
	return is_arm(zone) or is_leg(zone)


static func display_name(zone: Zone) -> String:
	return ["Cabeza", "Tórax", "Estómago", "Brazo izq.", "Brazo der.", "Pierna izq.", "Pierna der."][zone]
