# AGENTS.md

Instrucciones para agentes de código (Claude Code) que trabajan en este repositorio.
Survival FPS en Godot 4 · WoloGames. Diseño completo en `docs/GDD.md`: **léelo antes de implementar cualquier sistema**. Si una tarea contradice el GDD, detente y pregunta; no decidas diseño por tu cuenta.

---

## 1. Reglas no negociables

1. **Autoridad del host.** Todo cambio de estado de gameplay (daño, inventario, loot, construcción, IA, spawns) ocurre **solo en el host**. Los clientes envían solicitudes por RPC y el host valida. El single player es un host sin clientes: no escribas caminos de código separados para single y coop.
2. **Determinismo del mundo.** La generación del mundo nunca usa `randf()`, `randi()` ni `randomize()` globales. Cada fase usa su propio `RandomNumberGenerator` con seed `hash(world_seed, "nombre_fase")`. El orden de las fases es fijo. Cualquier cambio en la generación debe mantener verde el test de hash por seed.
3. **Terreno no modificable.** No implementes excavación, vóxeles ni deformación del terreno. La única modificación permitida es el aplanado bajo los POIs durante la generación.
4. **Datos separados de la lógica.** Las estadísticas de objetos, armas, munición, biomas, POIs, tablas de loot, recetas y perfiles de IA viven en Resources (`.tres`) dentro de `/data`. No pongas números de balance hardcodeados en el código.
5. **Un solo sistema de combate.** El jugador y los NPCs usan las mismas armas, la misma balística y el mismo daño por zonas. Nada de atajos exclusivos para la IA.
6. **No añadir dependencias sin aprobación.** No instales addons, plugins ni GDExtensions nuevos sin que un humano lo apruebe explícitamente. Revisa siempre la licencia.
7. **Sin secretos en el repo.** Ni claves, ni tokens, ni credenciales.

---

## 2. Stack

- Godot 4.x (la versión exacta está fijada en `project.godot` y en `.godot-version`). No cambies de versión sin aprobación.
- GDScript con **tipado estático obligatorio**.
- Addons aprobados: Terrain3D, LimboAI y gdUnit4.
- GDExtension (C++) solo si hay una medición del profiler que lo justifique y con aprobación previa.

---

## 3. Estructura del repositorio

```
/addons            Addons de terceros aprobados (no modificar)
/src
  /core            Autoloads: EventBus, GameState, SaveSystem, NetManager
  /world
    /generation    Pipeline de generación por fases
    /biomes
    /poi
  /player          Controlador FPS, salud por zonas, supervivencia
  /combat          Armas, balística, daño, armadura
  /items           ItemDefinition, ItemInstance
  /inventory       Modelo de rejillas y contenedores (sin UI)
  /loot
  /crafting
  /building
  /ai
    /common        Percepción, memoria, puntos de cobertura, LOD de IA
    /human         Tareas LimboAI y perfiles de NPCs humanos
    /zombie
  /net             RPCs, sincronización, validación de solicitudes
  /ui              Solo presentación; nunca modifica el estado directamente
/data              Resources .tres (balance y contenido)
/scenes            Escenas, prefabs de POIs
/tests             gdUnit4, espejo de /src
/docs              GDD.md, adr/ (decisiones de arquitectura)
```

---

## 4. Convenciones de código

- Archivos y carpetas en `snake_case`; clases en `PascalCase` con `class_name` cuando sean reutilizables; constantes en `UPPER_SNAKE_CASE`.
- Identificadores y código en inglés. Los comentarios y docstrings pueden ir en español.
- Tipa todo: variables, parámetros, retornos y arrays (`Array[ItemInstance]`).
- Prefiere composición (nodos componentes) a herencia profunda.
- La comunicación entre sistemas desacoplados pasa por señales o por `EventBus`. No uses `get_node()` con rutas largas hacia otros sistemas.
- La UI lee el estado y emite solicitudes; **nunca muta el modelo directamente**.
- Nada de lógica de gameplay en `_process` si puede ir en `_physics_process` o dirigida por eventos.
- Funciones de más de ~40 líneas: divídelas.

### Patrón de solicitud en red (obligatorio para acciones de gameplay)

```gdscript
# Cliente (o UI): pide
func request_move_item(item_id: StringName, target: StringName, cell: Vector2i, rotated: bool) -> void:
    _server_move_item.rpc_id(1, item_id, target, cell, rotated)

# Host: valida y aplica
@rpc("any_peer", "call_local", "reliable")
func _server_move_item(item_id: StringName, target: StringName, cell: Vector2i, rotated: bool) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    # validar que sender puede tocar item_id y target, y que el movimiento es legal
    # aplicar y replicar
```

---

## 5. Tests

- Framework: gdUnit4. Los tests van en `/tests`, replicando la ruta de `/src`.
- **Obligatorio tener tests** para: modelo de inventario (colocación, rotación, anidado, stacks), determinismo de la generación (hash por seed), cálculo de daño y armadura, tablas de loot, validación de solicitudes de red y el modelo de puntería de la IA (convergencia del error, límites de headshot).
- Los tests deben pasar en headless antes de dar una tarea por terminada.
- No borres ni desactives tests para que la suite pase. Si un test está mal, explícalo en la respuesta.

---

## 6. Rendimiento

- Objetivo: 60 FPS en hardware de gama media con 20 NPCs humanos y 50 zombis activos.
- Vegetación y props repetidos siempre con MultiMesh o el instanciador de Terrain3D.
- Aplica el LOD de IA (GDD §11.2). Los raycasts de percepción se hacen a intervalos, no en todos los frames.
- Si un cambio puede afectar al rendimiento (generación, IA, física), indica cómo lo has medido.

---

## 7. Flujo de trabajo del agente

1. Lee la sección del GDD correspondiente y el código existente del sistema.
2. Si la tarea es grande, propón un plan breve antes de implementar.
3. Trabaja en cambios pequeños y revisables, un sistema por PR.
4. Escribe o actualiza los tests y ejecútalos.
5. Si tomas una decisión de arquitectura relevante, añade un ADR corto en `docs/adr/NNNN-titulo.md` (contexto, decisión, alternativas).
6. En el resumen final indica: qué cambiaste, cómo lo has probado, qué queda pendiente y cualquier desviación del GDD.

**Todo PR generado por IA requiere revisión humana antes del merge.**

---

## 8. Qué NO hacer

- No implementar PvP ni nada que lo presuponga.
- No introducir estado de gameplay que solo exista en el cliente.
- No usar RNG global en la generación.
- No modificar el código dentro de `/addons`.
- No crear escenas gigantes con toda la lógica: un sistema por nodo o componente.
- No inventar valores de diseño que el GDD marca como abiertos (🔶): usa un placeholder claramente marcado y pregunta.
