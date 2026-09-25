class_name ItemUseEffect
extends Resource
## Efecto de usar un objeto. Las subclases implementan apply(); se ejecuta en el host.
## Devuelve true si el objeto se ha consumido (una unidad).


func can_apply(_user: Node) -> bool:
	return true


func apply(_user: Node) -> bool:
	return false
