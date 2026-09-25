# ADR 0002 — Terrain3D 1.0.2 sobre Godot 4.7.1

- **Estado:** aceptado
- **Fecha:** 2026-09-25
- **Relacionado:** GDD §4.1, §16 · AGENTS.md §2

## Contexto

El GDD fija Terrain3D como sistema de terreno (heightmap estático, no modificable). La última versión estable, 1.0.2 (mayo de 2026, MIT), declara soporte para "Godot 4.4–4.6+" y `compatibility_minimum = 4.4`, pero no menciona 4.7, que es la versión fijada en el repo.

## Verificación (spike en un proyecto aparte)

Terreno de 1024×1024 m generado por código con `FastNoiseLite` e importado con `Terrain3DData.import_images()` en regiones de 256 m:

- La extensión carga en 4.7.1 (Windows, Forward+).
- La importación de 1×1 km (16 regiones) tarda ~150–170 ms.
- `get_height()` devuelve la altura importada (error < 1e-6).
- La colisión funciona con `Terrain3DCollision.FULL_GAME`. El modo por defecto, `DYNAMIC_GAME`, solo genera colisión alrededor de la cámara.
- Renderiza correctamente con el material por defecto.
- Avisos no bloqueantes:
  - `instance_reset_physics_interpolation() is deprecated`: Terrain3D usa una API de 4.4 que 4.7 mantiene por compatibilidad.
  - `Resource file not found: res://` cuando no se asigna `data_directory` (terreno creado solo en runtime).

## Decisión

- Se instala Terrain3D 1.0.2 en `addons/terrain_3d` con los binarios de PC (Windows, Linux y macOS). Se eliminan los de Android, iOS y web porque el juego es solo para PC (GDD §2). No se modifica código del addon.
- El mundo se genera como datos puros (`WorldData`) y un `WorldBuilder` los vuelca en Terrain3D. La generación y sus tests no dependen del addon.
- Para el gameplay se usa colisión `FULL_GAME` mientras el mapa sea de hasta 2×2 km. Si el profiler lo justifica, se revisará con `DYNAMIC_GAME` y un radio alrededor de cada jugador.

## Alternativas

- **Terreno propio con `HeightMapShape3D` + mallas por chunks:** control total, pero hay que reimplementar LOD, texturizado y el instanciador de vegetación que Terrain3D ya resuelve.
- **Bajar a Godot 4.6:** va contra la versión fijada y no hace falta, porque 4.7.1 funciona.

## Consecuencias

- Al actualizar Godot o Terrain3D hay que repetir esta verificación. Los avisos de API deprecada desaparecerán cuando Terrain3D compile contra 4.7.
