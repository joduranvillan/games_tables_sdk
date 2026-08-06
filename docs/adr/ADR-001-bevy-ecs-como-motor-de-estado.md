# ADR-001: Bevy ECS como Motor de Estado Central

* **Fecha:** 2026-08-01
* **Estatus:** Aceptado

## Contexto

El SDK de OpenTable requiere administrar el estado de múltiples juegos de mesa heterogéneos (ajedrez, go, TEG, monopoly, cartas, etc.), con variantes en número de jugadores, visibilidad de información y reglas de turno. Se evaluaron enfoques orientados a objetos (jerarquías de clases por juego) y patrones ECS (Entity Component System).

## Decisión

Adoptar `bevy_ecs` como el motor de estado e infraestructura central en `open_table_engine`. Toda partida (`Session`) mantiene un `World` de ECS donde las piezas, casillas, cartas y jugadores son entidades con componentes y recursos asociados.

## Consecuencias Positivas

* **Modularidad y Desacoplamiento:** Estricta separación entre los datos (`Component` / `Resource`) y la lógica de negocio (`RuleEngine` y sistemas de reglas).
* **Flexibilidad:** Permite extender juegos o agregar mecánicas compuestas (ej. agregar temporalizador o efectos) adjuntando componentes sin modificar las estructuras existentes.
* **Inspección y Replay:** Facilita la serialización, sincronización y recreación determinista del mundo a partir del historial de comandos y eventos.

## Consecuencias Negativas

* **Curva de Aprendizaje:** Exige un cambio de paradigma hacia la programación orientada a datos (Data-Oriented Design) frente a modelos clasicos de OOP.
* **Overhead en Juegos Simples:** Para juegos con muy poco estado (como Damas o Ludo), la inicialización del `World` de ECS añade una pequeña abstracción adicional.
