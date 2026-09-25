class_name ItemDefinition
extends Resource
## Definición de un objeto (GDD §7.1). Valores en /data/items/*.tres.
## Un objeto puede enlazar con su definición de combate (arma, munición, armadura).

enum Category { WEAPON, AMMO, ARMOR, RIG, BACKPACK, MEDICAL, FOOD, MISC }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MISC
## Tamaño en celdas (ancho × alto) sin rotar.
@export var size: Vector2i = Vector2i.ONE
@export var rotatable: bool = true
@export var max_stack: int = 1
## Peso por unidad (kg).
@export var weight_kg: float = 0.0
## Rejillas internas si el objeto es un contenedor (mochila, rig, caja).
@export var container: ContainerSpec
## Color del icono provisional en la UI hasta tener arte.
@export var icon_color: Color = Color(0.5, 0.5, 0.5)

@export_group("Enlaces de combate")
@export var weapon: WeaponDefinition
@export var ammo: AmmoDefinition
@export var armor: ArmorDefinition

@export_group("Uso")
## Efecto al usar el objeto (vendas, comida...). Null si no se puede usar.
@export var use_effect: ItemUseEffect


func is_container() -> bool:
	return container != null and not container.grids.is_empty()


func is_stackable() -> bool:
	return max_stack > 1


## Tamaño ocupado con o sin rotar.
func footprint(rotated: bool) -> Vector2i:
	return Vector2i(size.y, size.x) if rotated else size
