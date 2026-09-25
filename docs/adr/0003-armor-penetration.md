# ADR 0003 — Penetración de armadura probabilística

- **Estado:** aceptado
- **Fecha:** 2026-09-25
- **Relacionado:** GDD §6 · decisión del usuario (probabilística, estilo Tarkov)

## Contexto

El GDD define la armadura por clases 1–6 con durabilidad, y la munición con "penetración frente a la clase de armadura", pero no especifica la fórmula. Había tres opciones: probabilística, umbral determinista o reducción porcentual. Se eligió la **probabilística**.

## Decisión

La calcula `DamageResolver.resolve_bullet()`, una función pura; el host aplica el resultado.

1. **Valor de la armadura:** `rating = clase × 10 × lerp(min_armor_effectiveness, 1, durabilidad / durabilidad_máx)`. Con la armadura destrozada, protege como una fracción de su clase (`min_armor_effectiveness`, 0.5 inicial).
2. **Probabilidad de penetrar:** una rampa lineal alrededor del valor de la armadura:
   `p = clamp(0.5 + (penetración − rating) / (2 × penetration_spread), 0, 1)`.
   Con `penetration_spread = 15`: una bala con penetración igual al valor de la armadura atraviesa el 50 % de las veces, y con ±15 lo hace siempre o nunca.
3. **Daño:**
   - Si atraviesa: `daño × penetrated_damage_factor`.
   - Si no atraviesa: daño romo, `daño × blunt_damage_factor`.
   - Sin armadura en la zona: daño completo.
4. **Desgaste:** `penetración × durability_loss_factor`, limitado a la durabilidad restante. Se desgasta tanto si la bala atraviesa como si no.
5. **Determinismo:** cada resolución consume exactamente una tirada del RNG que se le pasa (del host), haya armadura o no.

Todos los parámetros están en `data/combat/combat_rules.tres` y en cada `ArmorDefinition`. Son valores iniciales de tuning 🔶.

## Alternativas

- **Umbral determinista:** más legible, pero pierde la tensión de "¿habrá atravesado?" que busca el pilar de combate estilo Tarkov.
- **Reducción porcentual:** más simple, pero la armadura nunca bloquea del todo y las clases pierden peso.
- **Curva sigmoide:** más natural en los extremos, pero depende de `exp()`. La rampa lineal es suficiente y más fácil de balancear.

## Consecuencias

- La misma munición contra la misma armadura puede dar resultados distintos. Los tests comprueban la frecuencia, no un resultado concreto.
- El desgaste hace que una armadura castigada se atraviese cada vez más.
