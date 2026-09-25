class_name PhysicsLayers
## Capas de física (nombradas en project.godot > layer_names/3d_physics).

const WORLD: int = 1 << 0
const CHARACTERS: int = 1 << 1
const HITBOXES: int = 1 << 2
## Objetos con los que se interactúa con E (contenedores, objetos en el suelo).
const INTERACTABLES: int = 1 << 3
## Lo que detiene una bala: el mundo y las zonas de daño (no las cápsulas de movimiento).
const PROJECTILE_MASK: int = WORLD | HITBOXES
