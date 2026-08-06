# ADR-002: Uso de GDExtension (gdext) para el Bridge de Godot / Redot

* **Fecha:** 2026-08-01
* **Estatus:** Aceptado

## Contexto

OpenTable SDK ofrece un motor escrito en Rust puro, pero la capa de presentación y la interfaz de usuario se implementan en Godot 4 / Redot. Se requería una vía de comunicación de alto rendimiento y cero copia innecesaria entre Rust y GDScript.

## Decisión

Utilizar `gdext` (librería oficial `godot` de Rust para GDExtension, v0.2.4) en el crate `open_table_godot`. Se expone un nodo principal (`OpenTableBridge`) que abstrae los modos de juego (Local, Host TCP, Cliente TCP) mediante el enum interno `BridgeMode`.

## Consecuencias Positivas

* **Rendimiento Nativo:** Comunicación directa entre Rust y la máquina virtual de Godot sin el overhead de sockets o llamadas FFI manuales.
* **Integración con GDScript:** Exposición idiomática de métodos, variantes y señales (`turn_changed`, `event_json`, `move_rejected`, etc.).
* **Seguridad de Memoria:** Todo el manejo de estado de la partida ocurre dentro de las garantías de Rust antes de notificar a Godot.

## Consecuencias Negativas

* **Limitación de Clases en Runtime:** En `gdext 0.2.4`, registrar múltiples clases con `#[derive(GodotClass)]` en una misma extensión presenta limitaciones en el runtime de Godot, lo que obligó a fusionar los modos Host y Client en una única clase `OpenTableBridge`.
* **Compatibilidad con Forks:** Requiere shims de compilación (`api-custom` y `redot_gdext_shim.sh`) para compilar contra forks del motor como Redot.
