# open_table_core

Tipos y contratos fundacionales de OpenTable Engine.

Este crate no conoce ECS (`bevy_ecs`), red real (sockets, Nearby Connections), ni Godot. Define el vocabulario común (IDs, `Command`/`Event` como trait objects serializables, `Component`/`Resource`, `RandomService` determinista, `GameClock`, trait `Transport`) compartidos por todos los juegos de mesa y capas superiores del SDK.
