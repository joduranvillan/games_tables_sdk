// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! El "Rule Engine" del RFC (capítulo 16): Command → Validation → Rules →
//! Actions → Commit → Events.
//!
//! La pieza no trivial acá es que `open_table_engine` recibe comandos como
//! `Box<dyn Command>` (no conoce `RollDiceCommand` ni `PlayCardCommand`),
//! pero cada juego necesita lógica distinta por tipo de comando. La
//! solución: un registro indexado por `TypeId` que cada juego llena en su
//! propio `Plugin::build()`. Es el mismo patrón que un router HTTP: no
//! sabe qué hace cada handler, solo sabe a cuál llamar.

use std::any::{Any, TypeId};
use std::collections::HashMap;
use std::sync::Arc;

use bevy_ecs::world::World as BevyWorld;
use open_table_core::prelude::*;

use crate::session::LegalMoveGenerator;

/// Firma de un handler de regla: recibe el comando ya downcasteado (vía
/// `Any`) y el `World` de bevy_ecs, devuelve los eventos resultantes o un
/// error de validación.
type RuleFn =
    Box<dyn Fn(&dyn Any, &mut BevyWorld) -> EngineResult<Vec<Box<dyn Event>>> + Send + Sync>;

#[derive(Default)]
pub struct RuleEngine {
    handlers: HashMap<TypeId, RuleFn>,
    legal_move_generator: Option<Arc<dyn LegalMoveGenerator>>,
}

impl RuleEngine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_legal_move_generator(&mut self, generator: Box<dyn LegalMoveGenerator>) {
        self.legal_move_generator = Some(Arc::from(generator));
    }

    pub fn legal_move_generator(&self) -> Option<&Arc<dyn LegalMoveGenerator>> {
        self.legal_move_generator.as_ref()
    }

    pub fn legal_moves(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        self.legal_move_generator
            .as_ref()
            .map(|g| g.generate_candidates(world, player))
            .unwrap_or_default()
    }

    /// Registra la regla para un tipo de comando concreto. `C` es
    /// `RollDiceCommand`, `PlayCardCommand`, etc. — un tipo que vive en el
    /// crate del juego, nunca en el motor.
    pub fn register<C, F>(&mut self, handler: F)
    where
        C: Command + 'static,
        F: Fn(&C, &mut BevyWorld) -> EngineResult<Vec<Box<dyn Event>>> + Send + Sync + 'static,
    {
        let boxed: RuleFn = Box::new(move |any_cmd, world| {
            let cmd = any_cmd
                .downcast_ref::<C>()
                .expect("type id coincide pero el downcast falló: bug interno del RuleEngine");
            handler(cmd, world)
        });
        self.handlers.insert(TypeId::of::<C>(), boxed);
    }

    /// Ejecuta la regla registrada para el tipo concreto de `command`.
    /// Si nadie registró una regla para ese tipo, es `InvalidCommand`: un
    /// comando sin handler no puede pasar silenciosamente.
    pub fn dispatch(
        &self,
        command: &dyn Command,
        world: &mut BevyWorld,
    ) -> EngineResult<Vec<Box<dyn Event>>> {
        let any_cmd = command.as_any();
        let type_id = any_cmd.type_id();
        match self.handlers.get(&type_id) {
            Some(handler) => handler(any_cmd, world),
            None => Err(EngineError::InvalidCommand {
                reason: format!("ningún juego registró una regla para {command:?}"),
            }),
        }
    }
}
