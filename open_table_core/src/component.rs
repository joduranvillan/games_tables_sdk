// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// Un `Component` contiene únicamente datos, nunca lógica (I1 del RFC: un
/// Component nunca modifica otro Component).
///
/// A diferencia de `Command`/`Event`, acá NO usamos trait objects: cada
/// juego conoce sus propios componentes en tiempo de compilación (los usa
/// directo en sus `Query<T>`), así que no hace falta el mecanismo de
/// registro dinámico. `open_table_core` solo exige el contrato mínimo;
/// `open_table_engine` es quien lo mapea a `bevy_ecs::Component` real.
pub trait Component: std::fmt::Debug + Send + Sync + 'static {}
