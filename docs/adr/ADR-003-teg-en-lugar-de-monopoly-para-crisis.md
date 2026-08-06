# ADR-003: Reescritura de Crisis Game a Reglas Estilo TEG

* **Fecha:** 2026-08-03
* **Estatus:** Aceptado

## Contexto

El crate `crisis_game` se concibió inicialmente como un prototipo de juego de crisis/económico simplificado. Sin embargo, el SDK carecía de un motor de estrategia bélica y táctica de conquista global con mapa geográfico, tirada de dados de combate y objetivos secretos.

## Decisión

Reescribir el motor `crisis_game` para implementar el juego de estrategia TEG (Plan Táctico y Estratégico de Guerra), implementando un mapa mundial con 30 territorios agrupados en 6 continentes, objetivos secretos, tarjetas de ejércitos, combate simulado mediante dados y fases de reagrupamiento/canje.

## Consecuencias Positivas

* **Cobertura de Género:** Incorpora al SDK un referente de estrategia y conquista territorial multijugador.
* **Prueba de Estrés del SDK:** Ejercita la capacidad de `open_table_engine` para manejar información privada (objetivos secretos) y secuencias de combate deterministas con servicios de números aleatorios (`RandomService`).
* **Experiencia de Usuario Enriquecida:** Permite tableros con grafos de adyacencia geográficos reales en la vista de Godot.

## Consecuencias Negativas

* **Mayor Mayor Complejidad:** Aumentó significativamente la cantidad de comandos (`PlaceInitialArmiesCommand`, `AttackCommand`, `RegroupCommand`, `RedeemCardsCommand`) y eventos del crate.
* **Mantenimiento:** Mayor volumen de código y casos de borde en pruebas unitarias y de integración.
