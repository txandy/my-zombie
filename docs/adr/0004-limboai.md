# ADR 0004 — LimboAI 1.8.1 (GDExtension) sobre Godot 4.7.1

- **Estado:** aceptado
- **Fecha:** 2026-09-25
- **Relacionado:** GDD §11.2, §16 · AGENTS.md §2 (addon aprobado)

## Contexto

El GDD fija LimboAI para la IA de los NPCs humanos: una máquina de estados jerárquica de alto nivel (Idle/Patrulla → Alerta → Combate → Búsqueda → Retirada) y behavior trees dentro de cada estado. LimboAI se distribuye como módulo del motor (con builds propias de Godot) o como GDExtension.

## Verificación

- La versión más reciente es 1.8.1 (agosto de 2026, MIT). Ofrece una GDExtension compilada contra 4.6 (`compatibility_minimum = "4.2"`) y builds del motor 4.7.2.
- La GDExtension carga en Godot 4.7.1 en headless: `LimboHSM`, `LimboState`, `BTPlayer`, `BehaviorTree`, `BTAction`, `Blackboard` y `BTSequence` existen y se instancian.

## Decisión

- Se usa la **GDExtension**, no el módulo: el motor sigue siendo el oficial fijado en `.godot-version`.
- Se instala en `addons/limboai` solo con los binarios de PC (Windows y Linux x86_64, y macOS). Se eliminan los de Android, iOS y web. No se modifica código del addon.
- La jerarquía de estados usa `LimboHSM`/`LimboState` y el comportamiento táctico se implementa con tareas `BTAction` propias en GDScript. Las decisiones tácticas (qué cobertura, flanquear o retirarse) usan *utility scoring* dentro de las tareas (GDD §11.2).

## Alternativas

- **Módulo de LimboAI con su build de Godot 4.7.2:** obligaría a cambiar el ejecutable del motor fijado.
- **HSM y BT propios:** se evitaría la dependencia, pero va contra el GDD, que fija LimboAI.

## Consecuencias

- Al actualizar Godot hay que comprobar que la GDExtension sigue cargando.
- Los behavior trees se construyen por código (y se pueden guardar como `.tres`) para que se puedan testear en headless.
