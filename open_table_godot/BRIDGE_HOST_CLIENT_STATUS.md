# Status: Bridge Host/Cliente TCP (histórico — resuelto)

> **Este documento quedó desactualizado y se conserva solo como
> registro histórico del problema tal como se lo encontró.** El bug de
> gdext descripto abajo está resuelto — ver
> `GDEXT_INVESTIGATION.md` (sección "Resolución") para la solución
> aplicada, y `BRIDGE_USAGE.md` para la API actual de `CheckersBridge`.
> No usar este documento como referencia de la API: los nombres
> `CheckersBridgeHost`/`CheckersBridgeClient` que aparecen abajo **ya no
> existen** en el código.

## Lo que describía originalmente este documento

Un diseño con dos clases separadas, `CheckersBridgeHost` y
`CheckersBridgeClient`, cada una implementada y testeada en Rust puro,
pero bloqueadas por un problema de registro en gdext: cuando un
`.gdextension` tiene múltiples structs con `#[derive(GodotClass)]`,
gdext genera el código para ambas pero Godot solo ve la primera
(`Identifier "CheckersBridgeClient" not declared in the current
scope`, aun cuando el símbolo existe en el binary).

Las tres soluciones que se estaban evaluando en ese momento (actualizar
gdext, dos `.so` separados, o fusionar en una sola clase con dispatch
interno) están documentadas con más contexto en `GDEXT_INVESTIGATION.md`.
Se implementó la tercera: una única clase `CheckersBridge` con un enum
interno `BridgeMode { Local, Host, Client }`.
