//! Inteligencia Artificial heurística para Monopoly.
//!
//! Reglas de decisión:
//! - **Compra de propiedad**: compra si `cash > price * 2` o si la propiedad completa un grupo de color
//!   (siempre que tenga efectivo suficiente para cubrir el precio).
//! - **Subasta**: oferta hasta el `80%` del valor de mercado de la propiedad (`price * 80 / 100`).
//! - **Cárcel**: paga la fianza (`50$`) si hay propiedades no hipotecadas/disponibles que se puedan desarrollar.
//! - **Movimiento**: tira los dados y avanza (`RollAndMoveCommand`) cuando no hay decisiones pendientes.

#![allow(clippy::needless_range_loop, clippy::large_enum_variant)]

use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

use crate::board::{Space, SpaceKind};
use crate::commands::{
    AuctionBidCommand, BuildHouseCommand, BuyPropertyCommand, PayJailFeeCommand, RollAndMoveCommand,
};
use crate::resources::{
    AuctionResource, BoardResource, BuildingsResource, JailResource, PendingPurchaseResource,
    PlayersResource,
};
use crate::rules::house_cost_for_space;

/// Estado de partida de Monopoly.
pub type MonopolyState = Session;

/// Comando devuelto por la IA de Monopoly.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MonopolyCommand {
    RollAndMove(RollAndMoveCommand),
    BuyProperty(BuyPropertyCommand),
    PayJailFee(PayJailFeeCommand),
    AuctionBid(AuctionBidCommand),
    BuildHouse(BuildHouseCommand),
}

impl MonopolyCommand {
    /// Convierte el comando de IA en un `Box<dyn Command>` ejecutable por `Session`.
    pub fn into_command(self) -> Box<dyn Command> {
        match self {
            Self::RollAndMove(cmd) => Box::new(cmd),
            Self::BuyProperty(cmd) => Box::new(cmd),
            Self::PayJailFee(cmd) => Box::new(cmd),
            Self::AuctionBid(cmd) => Box::new(cmd),
            Self::BuildHouse(cmd) => Box::new(cmd),
        }
    }
}

/// Obtiene el precio de mercado de una casilla comprable.
pub fn space_market_price(space: &Space) -> Option<u32> {
    match space {
        SpaceKind::Property { price, .. }
        | SpaceKind::Railroad { price, .. }
        | SpaceKind::Utility { price, .. } => Some(*price),
        _ => None,
    }
}

/// Comprueba si comprar la casilla `space_idx` completaría el grupo de color para `player`.
pub fn completes_color_group(
    board_spaces: &[Space],
    players: &PlayersResource,
    player: PlayerId,
    space_idx: usize,
) -> bool {
    let Some(SpaceKind::Property { group, .. }) = board_spaces.get(space_idx) else {
        return false;
    };

    let group_indices: Vec<usize> = board_spaces
        .iter()
        .enumerate()
        .filter_map(|(idx, s)| match s {
            SpaceKind::Property { group: g, .. } if g == group => Some(idx),
            _ => None,
        })
        .collect();

    if group_indices.is_empty() {
        return false;
    }

    group_indices
        .iter()
        .all(|&idx| idx == space_idx || players.properties.get(&idx) == Some(&player))
}

/// Comprueba si existen propiedades no hipotecadas que se puedan adquirir o desarrollar en el tablero.
fn has_developable_unmortgaged_properties(
    board_spaces: &[Space],
    players: &PlayersResource,
    ai: PlayerId,
) -> bool {
    let ai_owns_property = players.properties.values().any(|&owner| owner == ai);
    let unowned_buyable_exists = board_spaces
        .iter()
        .enumerate()
        .any(|(idx, s)| space_market_price(s).is_some() && !players.properties.contains_key(&idx));
    ai_owns_property || unowned_buyable_exists
}

/// Selecciona la mejor jugada para `ai` en Monopoly según `difficulty`:
/// - Si hay subasta activa: oferta hasta el 80% del valor de mercado (o 0 para pasar).
/// - Si hay decisión de compra pendiente para `ai`: compra si `cash > price * 2` o si completa grupo de color.
/// - Si está en la cárcel en su turno y hay propiedades no hipotecadas que se puedan desarrollar: paga fianza.
/// - Si es su turno normal: lanza los dados (`RollAndMoveCommand`).
pub fn best_move(
    state: &MonopolyState,
    ai: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MonopolyCommand> {
    let board = state.world().get_resource::<BoardResource>()?;
    let players = state.world().get_resource::<PlayersResource>()?;

    if players.bankrupt.contains(&ai) {
        return None;
    }

    let cash = players.money.get(&ai).copied().unwrap_or(0);

    // 1. Subasta activa: ofertar hasta el 80% del valor de mercado
    if let Some(auction_res) = state.world().get_resource::<AuctionResource>() {
        if let Some(auction) = &auction_res.state {
            if !auction.passed.contains(&ai) && auction.highest_bidder != Some(ai) {
                let market_value = board
                    .spaces
                    .get(auction.space)
                    .and_then(space_market_price)
                    .unwrap_or(0);
                let max_bid = (market_value * 80) / 100;

                if auction.current_bid < max_bid && cash > auction.current_bid as i64 {
                    let step = match difficulty {
                        AiDifficulty::Easy => 20,
                        _ => 10,
                    };
                    let next_bid = (auction.current_bid + step)
                        .min(max_bid)
                        .min(cash.max(0) as u32);
                    if next_bid > auction.current_bid {
                        return Some(MonopolyCommand::AuctionBid(AuctionBidCommand {
                            player: ai,
                            amount: next_bid,
                        }));
                    }
                }

                return Some(MonopolyCommand::AuctionBid(AuctionBidCommand {
                    player: ai,
                    amount: 0,
                }));
            }
        }
    }

    // 2. Decisión de compra pendiente: comprar si cash > price * 2 o si completa un grupo de color
    if let Some(pending_res) = state.world().get_resource::<PendingPurchaseResource>() {
        if let Some(decision) = pending_res.pending.get(&ai) {
            let price = board
                .spaces
                .get(decision.space)
                .and_then(space_market_price)
                .unwrap_or(0);
            let completes_group = completes_color_group(&board.spaces, players, ai, decision.space);
            let affordable_double = cash > (price as i64) * 2;
            let can_afford = cash >= price as i64;

            let should_buy = can_afford && (affordable_double || completes_group);
            return Some(MonopolyCommand::BuyProperty(BuyPropertyCommand {
                player: ai,
                buy: should_buy,
            }));
        }
    }

    // Solo puede ejecutar acciones de turno si es el jugador actual
    if state.current_player() != ai {
        return None;
    }

    // 3. En la cárcel: pagar fianza si hay propiedades no hipotecadas que se puedan desarrollar y tiene >= 50$
    if let Some(jail_res) = state.world().get_resource::<JailResource>() {
        if jail_res.jailed.contains_key(&ai)
            && cash >= 50
            && has_developable_unmortgaged_properties(&board.spaces, players, ai)
        {
            return Some(MonopolyCommand::PayJailFee(PayJailFeeCommand {
                player: ai,
            }));
        }
    }

    // 4. Construir casas si posee un grupo de color completo y tiene más de $400 de reserva (Medium/Hard/Expert)
    if difficulty != AiDifficulty::Easy && cash > 400 {
        let buildings_res = state.world().get_resource::<BuildingsResource>();
        let empty_buildings = std::collections::HashMap::new();
        let buildings_map = buildings_res
            .map(|b| &b.buildings)
            .unwrap_or(&empty_buildings);

        for (space_idx, space) in board.spaces.iter().enumerate() {
            if let SpaceKind::Property { group, .. } = space {
                if players.properties.get(&space_idx) == Some(&ai)
                    && players.owns_full_group(&board.spaces, ai, group)
                {
                    // No se puede construir si alguna propiedad del grupo está hipotecada
                    let group_has_mortgaged = board.spaces.iter().enumerate().any(|(idx, s)| {
                        if let SpaceKind::Property { group: g, .. } = s {
                            g == group && players.mortgaged.contains(&idx)
                        } else {
                            false
                        }
                    });
                    if group_has_mortgaged {
                        continue;
                    }

                    let current_level = buildings_map.get(&space_idx).copied().unwrap_or(0);
                    if current_level >= 5 {
                        continue;
                    }

                    // Regla de construcción uniforme
                    let group_spaces: Vec<usize> = board
                        .spaces
                        .iter()
                        .enumerate()
                        .filter_map(|(idx, s)| match s {
                            SpaceKind::Property { group: g, .. } if g == group => Some(idx),
                            _ => None,
                        })
                        .collect();

                    let other_spaces: Vec<usize> = group_spaces
                        .into_iter()
                        .filter(|&idx| idx != space_idx)
                        .collect();

                    let min_other = other_spaces
                        .iter()
                        .map(|&idx| buildings_map.get(&idx).copied().unwrap_or(0))
                        .min()
                        .unwrap_or(0);

                    if current_level <= min_other {
                        let cost = house_cost_for_space(space_idx);
                        if cash >= cost as i64 {
                            return Some(MonopolyCommand::BuildHouse(BuildHouseCommand {
                                player: ai,
                                space: space_idx,
                            }));
                        }
                    }
                }
            }
        }
    }

    // 5. Tirar dados y avanzar
    Some(MonopolyCommand::RollAndMove(RollAndMoveCommand {
        player: ai,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_monopoly_session;
    use crate::resources::{AuctionState, PendingDecision};
    use std::collections::HashSet;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn monopoly_ai_buys_affordable_property() {
        let mut session = new_monopoly_session(SessionId(1), 42, P1, P2);

        // Casilla 1: Av. Mediterráneo (precio = 60$, grupo = "Marrón").
        // P1 tiene 1500$ (> 60 * 2 = 120$), por lo que debe comprarla.
        {
            let mut pending = session
                .world_mut()
                .resource_mut::<PendingPurchaseResource>();
            pending.pending.insert(
                P1,
                PendingDecision {
                    space: 1,
                    is_doubles: false,
                },
            );
        }

        let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            cmd,
            MonopolyCommand::BuyProperty(BuyPropertyCommand {
                player: P1,
                buy: true,
            })
        );

        // Si P1 solo tiene 100$ (<= 60 * 2 = 120$) y no completa el grupo, rechaza la compra.
        {
            let mut players = session.world_mut().resource_mut::<PlayersResource>();
            players.money.insert(P1, 100);
        }
        let reject_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            reject_cmd,
            MonopolyCommand::BuyProperty(BuyPropertyCommand {
                player: P1,
                buy: false,
            })
        );

        // Pero si ya posee la otra propiedad del grupo "Marrón" (casilla 3: Av. Báltica), sí la compra con 100$.
        {
            let mut players = session.world_mut().resource_mut::<PlayersResource>();
            players.properties.insert(3, P1);
        }
        let group_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            group_cmd,
            MonopolyCommand::BuyProperty(BuyPropertyCommand {
                player: P1,
                buy: true,
            })
        );

        // Verificar subasta hasta el 80% del valor de mercado (casilla 5: Ferrocarril Reading, precio = 200$, 80% = 160$)
        {
            session
                .world_mut()
                .resource_mut::<PendingPurchaseResource>()
                .pending
                .clear();
            session
                .world_mut()
                .resource_mut::<PlayersResource>()
                .money
                .insert(P1, 500);
            session.world_mut().resource_mut::<AuctionResource>().state = Some(AuctionState {
                space: 5,
                current_bid: 140,
                highest_bidder: Some(P2),
                passed: HashSet::new(),
            });
        }
        let bid_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            bid_cmd,
            MonopolyCommand::AuctionBid(AuctionBidCommand {
                player: P1,
                amount: 150,
            })
        );
    }

    #[test]
    fn monopoly_ai_builds_house_when_owning_group_and_has_reserve() {
        let mut session = new_monopoly_session(SessionId(1), 42, P1, P2);
        {
            let mut players = session.world_mut().resource_mut::<PlayersResource>();
            // P1 es dueño de ambas propiedades del grupo Marrón (casillas 1 y 3)
            players.properties.insert(1, P1);
            players.properties.insert(3, P1);
            players.money.insert(P1, 1000); // > 400$ de reserva
        }

        // En Hard, debe proponer construir casa en casilla 1
        let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            cmd,
            MonopolyCommand::BuildHouse(BuildHouseCommand {
                player: P1,
                space: 1,
            })
        );

        // En Easy, ignora la construcción y tira dados
        let easy_cmd = best_move(&session, P1, AiDifficulty::Easy).unwrap();
        assert_eq!(
            easy_cmd,
            MonopolyCommand::RollAndMove(RollAndMoveCommand { player: P1 })
        );

        // Si P1 tiene $400 o menos (ej: $350), no construye y tira dados
        {
            let mut players = session.world_mut().resource_mut::<PlayersResource>();
            players.money.insert(P1, 350);
        }
        let low_cash_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            low_cash_cmd,
            MonopolyCommand::RollAndMove(RollAndMoveCommand { player: P1 })
        );
    }
}
