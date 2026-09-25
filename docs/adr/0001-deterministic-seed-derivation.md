# ADR 0001 — Derivación determinista de seeds por fase

- **Estado:** aceptado
- **Fecha:** 2026-09-25
- **Relacionado:** GDD §4.2, AGENTS.md §1.2

## Contexto

El GDD exige que cada fase de la generación del mundo use su propio RNG con seed `hash(world_seed, "phase_name")` y que la misma seed produzca el mismo mundo byte a byte. Además, los clientes en coop regeneran el mundo localmente a partir de la seed (GDD §12), así que el resultado tiene que ser idéntico entre máquinas.

La función global `hash()` de Godot no sirve para esto:

- Solo acepta un `Variant`, así que habría que combinar los dos valores en un `Array`, y el hash de un `Array` depende de la implementación interna del Variant.
- Devuelve 32 bits, lo que desperdicia la mitad del espacio de una seed `int64`.
- Su algoritmo no forma parte de ninguna API estable y puede cambiar entre versiones del motor, lo que rompería partidas guardadas y el test de hash por seed.

## Decisión

1. La seed de cada fase se deriva con **FNV-1a de 64 bits**, implementado en GDScript en `SeedUtil.derive(world_seed: int, phase_name: StringName) -> int`:
   - Entrada: los 8 bytes de `world_seed` en little-endian, un byte separador `0x00` y los bytes UTF-8 de `phase_name`.
   - `offset_basis = 0xcbf29ce484222325` y `prime = 0x100000001b3`.
2. La implementación **no depende del desbordamiento de enteros con signo**: la multiplicación se hace por partes de 32 bits para que el resultado sea idéntico en cualquier compilador y plataforma.
3. Hay tests con **vectores conocidos** (valores esperados escritos a mano en el test), no solo con comprobaciones de "dos llamadas dan lo mismo".
4. Cada fase crea su propio `RandomNumberGenerator` y le asigna `rng.seed = SeedUtil.derive(world_seed, "phase_name")`. Nunca se usa `randf()`, `randi()` ni `randomize()` globales.
5. Los nombres de fase son constantes (`&"heightmap"`, `&"climate"`, `&"biomes"`, ...). Renombrar una fase cambia el mundo generado, así que se trata como un cambio incompatible.

## Alternativas consideradas

- **`hash([world_seed, phase_name])`:** es simple, pero no es estable entre versiones y solo da 32 bits.
- **`world_seed + phase_index`:** produce seeds muy correlacionadas entre fases, y reordenar o insertar fases cambia todo.
- **SHA-256 con `HashingContext`:** es estable, pero más lento y más verboso para algo que se llama unas pocas veces por generación. Queda como alternativa si FNV-1a diera problemas de calidad.

## Consecuencias

- La derivación de seeds es estable entre versiones de Godot y entre plataformas.
- El algoritmo interno de `RandomNumberGenerator` (PCG32) sí pertenece al motor. Por eso la versión de Godot está fijada en `.godot-version`, y el test de hash del mundo debe volver a ejecutarse antes de cambiarla.
