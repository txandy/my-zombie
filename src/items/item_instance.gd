class_name ItemInstance
extends RefCounted
## Un objeto concreto (GDD §7.1): uuid, definición, cantidad, durabilidad y estado.
## Si su definición es un contenedor, lleva su propio ItemContainer (anidado).
## Solo el host crea instancias; los ids son únicos por partida.

static var _next_serial: int = 1

var uuid: StringName
var definition: ItemDefinition
var quantity: int = 1
## Durabilidad actual (armaduras, armas). -1 si no aplica.
var durability: float = -1.0
## Estado libre por tipo de objeto. Armas: "rounds" (int) y "ammo" (id de munición cargada).
var state: Dictionary = {}
## Contenido si es un contenedor.
var contents: ItemContainer

## Contenedor que lo contiene ahora (referencia débil para no crear ciclos).
var _location: WeakRef


func _init(def: ItemDefinition, amount: int = 1, id: StringName = &"") -> void:
	definition = def
	quantity = clampi(amount, 1, maxi(def.max_stack, 1))
	uuid = id if id != &"" else StringName("item_%d" % _next_serial)
	if id == &"":
		_next_serial += 1
	if def.armor != null:
		durability = def.armor.max_durability
	if def.is_container():
		contents = ItemContainer.new(StringName("%s/contents" % uuid), def.container.grids, self)


## Contenedor que lo contiene, o null si está suelto (suelo, slot de equipo...).
func location() -> ItemContainer:
	return _location.get_ref() as ItemContainer if _location != null else null


func set_location(container: ItemContainer) -> void:
	_location = weakref(container) if container != null else null


func weight_kg() -> float:
	var total: float = definition.weight_kg * quantity
	if contents != null:
		total += contents.total_weight()
	return total


## True si `other` es este objeto o está dentro de él (a cualquier profundidad).
func contains_or_is(other: ItemInstance) -> bool:
	var container: ItemContainer = other.location()
	if other == self:
		return true
	while container != null:
		var holder: ItemInstance = container.owner_item()
		if holder == null:
			return false
		if holder == self:
			return true
		container = holder.location()
	return false


func can_stack_with(other: ItemInstance) -> bool:
	return (other != self and other.definition == definition and definition.is_stackable()
			and contents == null and other.contents == null)


## Separa `amount` unidades en una instancia nueva (sin ubicar). Null si no se puede.
func split(amount: int) -> ItemInstance:
	if amount <= 0 or amount >= quantity:
		return null
	quantity -= amount
	return ItemInstance.new(definition, amount)


## Pasa todas las unidades que quepan de `source` a este stack. Devuelve cuántas ha pasado.
func merge_from(source: ItemInstance) -> int:
	if not can_stack_with(source):
		return 0
	var moved: int = mini(source.quantity, definition.max_stack - quantity)
	quantity += moved
	source.quantity -= moved
	return moved


## Para restaurar partidas guardadas (M6): el siguiente id no puede repetir uno existente.
static func reserve_serial(serial: int) -> void:
	_next_serial = maxi(_next_serial, serial + 1)
