# ADR 0005 — Modelo de red del coop

- **Estado:** aceptado
- **Fecha:** 2026-09-25
- **Relacionado:** GDD §12 · AGENTS.md §1.1, §4 · M7

## Contexto

El GDD fija un listen server con el host como autoridad total, el single player como host sin clientes, la predicción del movimiento propio con corrección del host y la regeneración local del mundo a partir de la seed. Desde M0 toda acción de gameplay es una solicitud al host (`request_*` → RPC → validación). En M7 faltaba replicar el resultado a los clientes.

## Decisión

1. **Conexión y mundo:**
   - El cliente envía su nombre (`_server_hello`) y el host le responde con la seed y el hash del mundo.
   - El cliente **regenera el mundo localmente** y compara hashes; si no coinciden, se desconecta (no puede haber desincronización del mundo).
   - Después se marca como *listo* (`NetManager.mark_ready`). Solo los peers listos reciben la replicación: todos los `MultiplayerSynchronizer` llevan un filtro de visibilidad, y los spawners solo crean nodos en peers con visibilidad.
2. **Jugadores** (`MultiplayerSpawner` con función propia):
   - El **dueño simula su movimiento** (predicción) y sincroniza posición, rotación, velocidad, postura, pitch y suelo.
   - El host **valida la velocidad** y, si es imposible, **corrige** al cliente por RPC (`_client_correct`).
   - Todo lo demás es del host: salud, supervivencia, inventario (con los contenedores abiertos), arma actual y munición. El host lo envía al dueño en snapshots a 10 Hz, y al instante si cambia el inventario o el arma.
   - El retroceso y los rechazos llegan como RPC de feedback.
3. **Entidades del mundo:**
   - **Zombis y objetos en el suelo:** los crea el host con spawners y sincroniza su transformación y estado.
   - **NPCs:** son deterministas (existen en todos los peers). Solo el host tiene su cerebro y su equipo; los clientes reciben posición, postura y muerte.
   - **Bases:** replicación por RPC de pieza añadida, cambiada o eliminada y puertas, más un estado completo al unirse.
   - **Hora:** se sincroniza cada segundo.
   - **Impactos:** se reenvían para los efectos y el hitmarker.
4. **Validaciones del host en las solicitudes:**
   - El emisor es el dueño.
   - El objeto o destino está a su alcance.
   - Distancias de interacción, construcción y recogida.
   - El origen del disparo está a menos de 3 m del cuerpo del tirador.
5. **Guardado:** un archivo por jugador; el host es `host` y cada cliente usa su nombre.
6. **Verificación:** `tools/coop_soak.tscn` lanza dos procesos (host y cliente) que juegan un día acelerado y comparan su estado cada 5 s. Se considera desincronización una diferencia que persiste en dos comprobaciones seguidas. Se ejecuta en la CI.

## Alternativas

- **Simular en el host el movimiento de todos con los inputs de los clientes** (sin autoridad de posición del cliente): es más seguro, pero requiere rollback/reconciliación para que el movimiento propio se sienta bien. La validación de velocidad cubre el caso de trampa más simple.
- **Replicar inventarios como objetos de red:** es más fino, pero mucho más complejo. Los snapshots del dueño son pequeños (decenas de objetos).

## Consecuencias

- 🔶 **La compensación de lag** de los disparos es básica: el host usa las posiciones que tiene en ese momento (GDD §18.6, abierta).
- 🔶 **La stamina de los jugadores remotos** se cobra en el host a partir de su velocidad sincronizada; apuntar no se cobra en remoto.
- Los clientes no oyen sonidos de otros jugadores (aún no hay audio).
