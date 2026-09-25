# GDD v0.1 — [Nombre provisional]

> Survival FPS en Godot 4 · WoloGames · Single + coop (host autoritativo)
> Estado: borrador v0.1. Los valores numéricos son **valores iniciales de tuning**, no definitivos.
> Las secciones marcadas con 🔶 contienen decisiones abiertas (ver §18).

---

## 1. Visión

Survival en primera persona en un mundo abierto generado por seed. El jugador saquea, construye su base y sobrevive a zombis y, sobre todo, a humanos armados que saben combatir. La tensión viene de enemigos competentes y de un inventario que obliga a decidir qué te llevas.

**Pitch:** *El mundo de Rust, la supervivencia y las hordas de 7 Days to Die, y el combate e inventario de Escape from Tarkov.*

### 1.1 Pilares

1. **Enemigos humanos competentes y justos.** Disparan bien, usan cobertura y flanquean, pero siempre hay un tiempo de reacción y un margen para que el jugador responda. La muerte debe sentirse merecida, no arbitraria.
2. **Cada partida, un mundo nuevo.** Mapas generados por seed con biomas diferenciados y POIs hechos a mano, colocados proceduralmente.
3. **El inventario es gameplay.** Rejilla estilo Tarkov: el espacio es un recurso y organizar es una decisión.
4. **Tu base, tu refugio.** Construcción modular por piezas que debe resistir hordas y asaltos.

### 1.2 Referencias

| Juego | Qué tomamos | Qué NO tomamos |
|---|---|---|
| Rust | Generación por seed, POIs/monumentos, construcción por sockets | PvP, wipes, terreno de un solo bioma dominante |
| 7 Days to Die | Biomas con dificultad, hordas, ciclo día/noche, loot en POIs | Terreno vóxel modificable, estética |
| Escape from Tarkov | Inventario en rejilla, balística, daño por zonas, IA agresiva | Extracción como bucle principal, IA con aimbot |

---

## 2. Alcance

**Incluido:**
- Single player y coop de 2–4 jugadores (listen server, host autoritativo).
- Mundo procedural por seed, persistente por partida.
- Construcción, loot, crafting básico, supervivencia (comida, agua, heridas).

**Explícitamente fuera de alcance:**
- PvP.
- Terreno modificable o deformable (sin vóxeles ni excavación).
- Servidores dedicados persistentes (no se descarta a futuro, pero no condiciona el diseño actual).
- Plataformas distintas de PC.

---

## 3. Bucle de juego

- **Momento a momento:** explorar, detectar amenazas, combatir o evitar, y saquear.
- **Sesión (1 día de juego):** salir de la base, saquear un POI, volver antes de la noche, y craftear o reforzar la base.
- **Largo plazo:** mejorar el equipo, avanzar a biomas más peligrosos con mejor loot, y sobrevivir a hordas cada vez más duras.

**Curva de riesgo/recompensa:** la dificultad y la calidad del loot escalan por bioma y por tier de POI. El jugador elige su nivel de riesgo al elegir a dónde ir.

---

## 4. Mundo

### 4.1 Parámetros

| Parámetro | Valor inicial |
|---|---|
| Tamaño del mapa | 2×2 km (vertical slice: 1×1 km); máximo previsto 4×4 km |
| Seed | `int64`, introducible por el jugador o aleatoria |
| Terreno | Heightmap estático (Terrain3D), no modificable |
| Duración del día | 60 min reales (configurable) |

### 4.2 Pipeline de generación (determinista)

Cada fase recibe un RNG derivado: `hash(world_seed, "phase_name")`. El orden de las fases es fijo, y la misma seed debe producir **el mismo mundo byte a byte**.

1. **Heightmap:** combinación de capas `FastNoiseLite` (forma continental, montañas, detalle), máscara de costa en los bordes y erosión simple opcional.
2. **Clima:** ruido de temperatura y de humedad (baja frecuencia), modulado por la altura.
3. **Biomas:** se asignan a partir de temperatura, humedad y altura, con transición suavizada en los bordes.
4. **Ríos y lagos:** trazado desde zonas altas siguiendo la pendiente.
5. **POIs:** colocación por reglas (§4.4) y aplanado del terreno bajo su huella.
6. **Carreteras:** splines que conectan POIs de tier medio y alto, adaptadas a la pendiente.
7. **Splatmap:** texturas del terreno según bioma, pendiente y carreteras.
8. **Vegetación y rocas:** instanciado con MultiMesh según bioma, con exclusión en carreteras, POIs y ríos.
9. **Spawns:** puntos de spawn de zombis y NPCs, y zona de aparición del jugador (bioma seguro).

El resultado se cachea en disco dentro de la carpeta de la partida. Cargar una partida no regenera el mundo.

### 4.3 Biomas 🔶

| Bioma | Dificultad | Rasgos | Amenazas principales |
|---|---|---|---|
| Bosque templado | 1 | Recursos abundantes, visibilidad media | Zombis básicos, carroñeros |
| Pradera / granjas | 1–2 | Campo abierto, larga distancia de visión | Carroñeros, francotiradores ocasionales |
| Desierto | 2–3 | Calor (sed), pocos recursos, visibilidad alta | Bandidos, zombis rápidos |
| Nieve / montaña | 3 | Frío, pocos recursos, POIs militares | Militares desertores |
| Zona quemada / contaminada | 4 | Radiación o toxicidad, loot de tier alto | Zombis especiales, facción de élite |

### 4.4 POIs

- Se hacen **a mano** como escenas (`.tscn`). Cada una declara en su metadata: huella, tier, biomas permitidos, pendiente máxima, distancia mínima a otros POIs, marcadores de loot, marcadores de spawn, **puntos de cobertura** y navmesh horneado.
- **Tiers:** 1 (casas, gasolineras), 2 (supermercados, granjas grandes), 3 (comisarías, fábricas), 4 (bases militares, hospitales).
- **Pueblos:** agrupaciones de POIs de tier 1–2 alrededor de una carretera, generadas como una "plantilla de pueblo".

### 4.5 Día, noche y hordas

- De noche los zombis son más rápidos y agresivos y la visibilidad baja mucho.
- **Horda periódica** cada N días (inicialmente 7): oleadas dirigidas a la posición del jugador o de la base. Escala con el día y con el número de jugadores.

---

## 5. Jugador

### 5.1 Salud por zonas (estilo Tarkov simplificado)

| Zona | HP | Si llega a 0 |
|---|---|---|
| Cabeza | 35 | Muerte |
| Torso | 80 | Muerte |
| Estómago | 70 | Deshidratación y hambre aceleradas |
| Brazos (×2) | 60 | Peor puntería y recarga más lenta; el daño se redistribuye |
| Piernas (×2) | 65 | Movimiento lento, no puede esprintar; el daño se redistribuye |

- **Estados:** sangrado leve y grave, fractura, dolor (temblor en la mira), infección (mordeduras de zombi).
- **Supervivencia:** hambre, sed y temperatura corporal según el bioma.
- **Resistencia:** esprintar, saltar y apuntar consumen stamina.

### 5.2 Movimiento

Andar, esprintar, agacharse, tumbarse, asomarse (lean) y saltar. El ruido que se genera depende de la postura, la velocidad y la superficie, y alimenta la percepción de la IA (§11.2).

---

## 6. Combate y armas

- **Balística:** proyectiles simulados con raycast por tick de física (velocidad inicial y gravedad). La penetración queda para una fase posterior.
- **Armas:** estadísticas base (daño, cadencia, retroceso, dispersión) más modificaciones de accesorios (fase posterior).
- **Munición:** cada tipo tiene su propio daño, su penetración frente a la clase de armadura y su velocidad.
- **Armadura:** clases 1–6 por zona cubierta (casco y chaleco), con durabilidad.
- **Melee:** armas cuerpo a cuerpo para zombis y para ahorrar munición.
- **El jugador y los NPCs usan exactamente el mismo sistema de armas y de daño.**

---

## 7. Inventario

### 7.1 Modelo

- **ItemDefinition** (Resource, en `/data/items`): id, nombre, tamaño `w×h`, si es rotable, stack máximo, peso, categoría y, opcionalmente, `ContainerSpec` (una o varias rejillas internas).
- **ItemInstance:** uuid, referencia a la definición, cantidad, durabilidad y estado (por ejemplo, la munición que tiene un cargador).
- **Container:** una o varias rejillas; cada rejilla es una matriz de ocupación.

### 7.2 Reglas

- Colocar un objeto exige que todas las celdas de su huella (ya rotada) estén libres.
- **Contenedores anidados:** una mochila dentro de otro contenedor conserva su contenido. Un contenedor no puede meterse dentro de sí mismo ni de sus descendientes.
- **Slots de equipo:** casco, chaleco o rig, mochila, arma principal, arma secundaria, pistola, melee. El rig y la mochila aportan sus rejillas al inventario.
- **Peso:** a partir de un umbral penaliza la stamina y la velocidad.
- **Acciones:** mover, rotar, dividir y unir stacks, uso rápido (atajos 4–0), examinar y tirar.

### 7.3 Red

El cliente **solicita** las operaciones (`request_move_item(...)`) y el host valida, aplica y replica. El cliente puede mostrar una predicción visual, pero el estado real es siempre el del host.

---

## 8. Loot

- **Tablas de loot** (Resource) por tipo de contenedor (nevera, taquilla, caja militar, cuerpo), modificadas por el tier del POI y por el bioma.
- Los contenedores de los POIs se rellenan cuando el jugador entra en su radio por primera vez y se reponen tras N días (🔶).
- Los NPCs muertos sueltan **lo que llevaban equipado de verdad**: su equipo se genera con las mismas tablas y lo usan en combate.

---

## 9. Crafting

- Recetas (Resource): ingredientes, estación requerida, tiempo y resultado.
- **Estaciones:** a mano, banco de trabajo, forja, banco de armas y química (fases).
- En la v0.1 el crafting es básico: munición simple, vendas, piezas de construcción y reparaciones.

---

## 10. Construcción

- **Sistema por piezas con sockets** (estilo Rust): cimiento, cimiento triangular, pared, pared con puerta o ventana, suelo o techo, escaleras, puerta, ventana y pilar.
- **Materiales por tier:** madera, piedra, metal y reforzado. Se pueden mejorar sin tener que reconstruir.
- **Terreno no modificable:** los cimientos se extienden con pilares hasta el suelo, hasta una altura máxima.
- **Colocación:** preview fantasma, snap a sockets, validación de colisión y de terreno. El host valida siempre.
- **Daño:** cada pieza tiene HP según su material. Los zombis de la horda y los NPCs pueden atacar la base.
- **Integridad estructural:** fuera de la v0.1 (🔶).
- **Persistencia:** la base se guarda como datos (tipo, material, transform, HP), no como una escena serializada.
- **Claim / herramienta de propiedad:** 🔶 (solo relevante en coop).

---

## 11. Enemigos e IA

### 11.1 Zombis

| Tipo | Rasgos |
|---|---|
| Básico | Lento de día y rápido de noche, se guía por el oído y el olfato |
| Corredor | Rápido siempre, frágil |
| Tanque | Mucho HP, destruye piezas de la base |
| Especial (fase posterior) | Vomita, explota, etc. |

La IA de los zombis es **barata a propósito**: percepción simplificada, navegación compartida hacia un objetivo común en las hordas y animación reducida a distancia.

### 11.2 NPCs humanos — el pilar diferencial

**Arquetipos iniciales 🔶:** Carroñero (equipo pobre, asustadizo), Bandido (medio, agresivo, en grupo), Militar desertor (bien equipado, táctico) y Élite (fase posterior).

**Percepción**
- Cono de visión con raycasts a varios huesos del objetivo (cabeza, torso, pelvis y extremidades).
- **Visibilidad** del objetivo según luz, distancia, postura, movimiento y vegetación. La detección se acumula con el tiempo en lugar de ser instantánea.
- **Oído:** eventos de sonido globales (disparos, pasos, puertas, construcción) con radio y atenuación.
- **Memoria:** última posición conocida, con confianza que decae.

**Modelo de puntería (clave para que sea difícil pero justo)**
- **Tiempo de reacción** antes del primer disparo tras detectar: 0.25–0.8 s según arquetipo.
- **Error de apuntado** (cono angular) que parte de `base_spread` y **converge** hacia `min_spread` durante `aim_settle_time` mientras mantiene el objetivo a la vista.
- El error aumenta con la distancia, el movimiento del objetivo, el movimiento del propio NPC, estar recibiendo fuego (supresión) y sus propias heridas en los brazos.
- **Selección de zona:** torso por defecto. La probabilidad de apuntar a la cabeza sube con el asentamiento y se limita con `max_headshot_chance` según arquetipo.
- Si el NPC pierde de vista al objetivo, su puntería se "desasienta" parcialmente.
- Todos estos parámetros viven en un `NPCCombatProfile` (Resource) para poder ajustarlos sin tocar código.

**Tácticas**
- Buscar y usar cobertura (puntos de cobertura de los POIs más puntos generados en el terreno).
- Asomarse y disparar, recargar a cubierto.
- **En grupo:** un NPC suprime mientras otro flanquea, con comunicación simple a través de un "blackboard de escuadra".
- Retirarse y curarse con poca vida, y rendirse o huir (los carroñeros).
- Lanzar granadas si el objetivo está atrincherado (fase posterior).
- Buscar en la última posición conocida con patrón de búsqueda.

**Arquitectura**
- **LimboAI:** una máquina de estados de alto nivel (Idle/Patrulla → Alerta → Combate → Búsqueda → Retirada) y behavior trees dentro de cada estado.
- **Utility scoring** para decisiones tácticas: qué cobertura usar, si flanquear, si retirarse.
- **LOD de IA:** simulación completa a menos de 150 m de cualquier jugador, simplificada entre 150 y 400 m, y congelada o abstracta más allá.

**Criterio de aceptación de la IA:** en playtest, un jugador expuesto y quieto a 50 m de un bandido debe recibir impactos en 1–2 s. Un jugador que se mueve entre coberturas debe poder ganar el combate con habilidad. Si los testers describen al NPC como "aimbot" o como "tonto", el tuning no está terminado.

---

## 12. Coop y red

- **Listen server:** un jugador es el host y tiene autoridad total. **El single player es un host sin clientes**, con el mismo código.
- El host simula la IA, la física de gameplay, el loot, el inventario, el daño y la construcción. Los clientes envían inputs y solicitudes.
- **Movimiento del jugador:** el cliente predice su propio movimiento y el host corrige.
- **Impactos:** el host valida los disparos; lag compensation básica 🔶.
- Base técnica: la API de multijugador de alto nivel de Godot (ENet, `MultiplayerSpawner`, `MultiplayerSynchronizer` y RPCs).
- **Sincronización del mundo:** los clientes reciben la seed y regeneran el mundo localmente (es determinista). Solo se replica el estado dinámico.

---

## 13. Guardado

- La carpeta de la partida contiene la seed, la caché del mundo generado, el estado dinámico (contenedores saqueados, bases, NPCs y zombis persistentes, día y hora) y un archivo por jugador.
- Formato versionado (`save_version`) con migraciones.
- Autoguardado periódico y al dormir.

---

## 14. UI / HUD

- HUD mínimo: brújula, estado de salud por zonas (solo al recibir daño o al consultarlo), stamina e indicadores de hambre y sed cuando son críticos.
- Pantalla de inventario con rejillas, slots de equipo, contenedor abierto o suelo al lado, y ficha de objeto al examinar.
- Mapa del mundo generado a partir del heightmap y los biomas (no hay mapa hecho a mano).

---

## 15. Arte y audio

- 🔶 Dirección visual pendiente. Durante el desarrollo se usan placeholders y assets CC0 o de marketplace; ningún sistema debe depender del arte final.
- El audio es gameplay: los disparos y los pasos deben ser posicionales y reconocibles, porque la IA y el jugador se orientan por el sonido.

---

## 16. Tecnología

| Área | Decisión |
|---|---|
| Motor | Godot 4.x estable (versión fijada en el repo) |
| Lenguaje | GDScript con tipado estático; GDExtension (C++) solo en hot paths medidos con el profiler |
| Terreno | Terrain3D |
| IA | LimboAI + NavigationServer3D |
| Tests | gdUnit4 (ejecutables en headless / CI) |
| Red | Multiplayer de alto nivel de Godot, ENet |

---

## 17. Roadmap por hitos

Cada hito termina con una build jugable y sus criterios cumplidos.

| Hito | Contenido | Criterio de aceptación |
|---|---|---|
| **M0 — Fundaciones** | Estructura del repo, autoloads, tests en headless, controlador FPS básico | Los tests pasan en CI; el jugador se mueve por una escena de pruebas |
| **M1 — Mundo** | Pipeline de generación (fases 1–3, 5, 8) en 1×1 km, 2 biomas, 3 POIs | La misma seed produce el mismo hash de mundo; la generación tarda menos de 30 s |
| **M2 — Combate** | Armas, balística, daño por zonas y armadura | El jugador puede matar dummies y sufrir daño con estados |
| **M3 — Inventario y loot** | Rejillas, contenedores anidados, equipo y tablas de loot | Tests del modelo de inventario completos; se puede saquear un POI |
| **M4 — IA humana** | Un arquetipo (Bandido) con percepción, puntería y cobertura | Se cumple el criterio de §11.2 en playtest |
| **M5 — Supervivencia y zombis** | Hambre, sed, zombis básicos, día/noche | Un ciclo de día completo es jugable |
| **M6 — Construcción y guardado** | Piezas de madera y piedra, guardar y cargar | La base persiste tras cargar la partida |
| **M7 — Coop** | 2 jugadores en listen server | Dos jugadores completan un ciclo de día juntos sin desincronización |
| **Vertical slice** | M0–M7 integrados | Sesión de 1 h divertida con 3 testers externos |

> Nota: el coop entra en M7, pero **toda la arquitectura desde M0 respeta la autoridad del host** (§12), para que M7 sea conectar la red y no reescribir el juego.

---

## 18. Decisiones abiertas

1. Nombre del juego.
2. Lista final de biomas y arquetipos de NPC.
3. Reposición de loot: por tiempo, por día o nunca.
4. Integridad estructural en la construcción.
5. Sistema de claim y propiedad de la base en coop.
6. Nivel de lag compensation.
7. Dirección de arte.
8. Progresión del personaje: habilidades, niveles o solo equipo.
9. Facciones de NPCs con las que se pueda comerciar (¿traders?).
