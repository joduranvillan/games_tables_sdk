//! Inteligencia Artificial con Monte Carlo Tree Search (MCTS) y heurísticas tácticas para Crisis / TEG.
//!
//! Cubre las tres fases principales del turno:
//! - **Colocación (`PlaceArmies`)**: refuerza el territorio propio más amenazado
//!   (menor ratio `ejércitos_propios / ejércitos_vecinos_enemigos`).
//! - **Ataque (`Attack`)**: ataca si `ejércitos_atacantes > ejércitos_defensores * umbral`
//!   (`Easy`: `2.0`, `Medium`/`Hard`: `1.5`, `Expert`: `1.2`), evaluando con rollouts MCTS
//!   la probabilidad de conquista. En `Expert`, prioriza objetivos que acercan al `ObjectiveCard` secreto.
//! - **Fortificación (`Fortify`)**: mueve ejércitos excedentes al territorio fronterizo más débil conectado.

#![allow(
    clippy::needless_range_loop,
    clippy::large_enum_variant,
    clippy::too_many_arguments
)]

use std::collections::VecDeque;

use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

use crate::board::{are_adjacent, ObjectiveCard, TerritoryId, CONTINENTS, TERRITORIES};
use crate::commands::{
    DeclareAttackCommand, EndPhaseCommand, ExchangeCardsCommand, FortifyCommand,
    PlaceArmiesCommand, RollAttackCommand,
};
use crate::resources::{
    PendingAttackResource, PlayerCardsResource, PlayerObjectivesResource, TerritoryStateResource,
    TurnPhase, TurnStateResource,
};
use crate::rules::is_valid_card_set;

/// Estado de partida de Crisis/TEG.
pub type CrisisState = Session;

/// Comando emitido por la IA de Crisis/TEG.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum CrisisCommand {
    PlaceArmies(PlaceArmiesCommand),
    DeclareAttack(DeclareAttackCommand),
    RollAttack(RollAttackCommand),
    Fortify(FortifyCommand),
    EndPhase(EndPhaseCommand),
    ExchangeCards(ExchangeCardsCommand),
}

impl CrisisCommand {
    /// Convierte el comando de IA en un `Box<dyn Command>` ejecutable por `Session`.
    pub fn into_command(self) -> Box<dyn Command> {
        match self {
            Self::PlaceArmies(cmd) => Box::new(cmd),
            Self::DeclareAttack(cmd) => Box::new(cmd),
            Self::RollAttack(cmd) => Box::new(cmd),
            Self::Fortify(cmd) => Box::new(cmd),
            Self::EndPhase(cmd) => Box::new(cmd),
            Self::ExchangeCards(cmd) => Box::new(cmd),
        }
    }
}

/// Generador pseudoaleatorio rápido (XorShift64) para simulaciones MCTS de combate.
struct FastRng {
    state: u64,
}

impl FastRng {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 0x9e37_79b9_7f4a_7c15 } else { seed },
        }
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }

    fn roll_d6(&mut self) -> u8 {
        ((self.next_u64() % 6) + 1) as u8
    }
}

/// Umbral de superioridad numérica requerido para declarar un ataque según la dificultad.
pub fn attack_ratio_threshold(difficulty: AiDifficulty) -> f64 {
    match difficulty {
        AiDifficulty::Easy => 2.0,
        AiDifficulty::Medium | AiDifficulty::Hard => 1.5,
        AiDifficulty::Expert => 1.2,
    }
}

/// Devuelve todos los territorios adyacentes a `territory`.
pub fn adjacent_territories(territory: TerritoryId) -> Vec<TerritoryId> {
    (0..30u8)
        .map(TerritoryId)
        .filter(|&other| are_adjacent(territory, other))
        .collect()
}

/// Suma total de ejércitos enemigos en territorios adyacentes a `territory`.
pub fn enemy_neighbor_armies(
    map: &TerritoryStateResource,
    player: PlayerId,
    territory: TerritoryId,
) -> u32 {
    adjacent_territories(territory)
        .into_iter()
        .filter(|adj| map.owners.get(adj).copied() != Some(player))
        .map(|adj| map.armies.get(&adj).copied().unwrap_or(0))
        .sum()
}

/// Ratio `ejércitos_propios / ejércitos_vecinos_enemigos`.
/// Cuanto menor es este valor, más amenazado está el territorio.
/// Si no tiene vecinos enemigos (territorio interior), devuelve `f64::INFINITY`.
pub fn threat_ratio(
    map: &TerritoryStateResource,
    player: PlayerId,
    territory: TerritoryId,
) -> f64 {
    let enemy_armies = enemy_neighbor_armies(map, player, territory);
    if enemy_armies == 0 {
        return f64::INFINITY;
    }
    let own_armies = map.armies.get(&territory).copied().unwrap_or(0);
    (own_armies as f64) / (enemy_armies as f64)
}

/// Comprueba si dos territorios propios están conectados a través de una cadena de territorios de `owner`.
pub fn are_connected_by_owner(
    from: TerritoryId,
    to: TerritoryId,
    owner: PlayerId,
    map: &TerritoryStateResource,
) -> bool {
    if from == to {
        return true;
    }
    let mut visited = [false; 30];
    let mut queue = VecDeque::new();
    queue.push_back(from);
    if (from.0 as usize) < 30 {
        visited[from.0 as usize] = true;
    }

    while let Some(curr) = queue.pop_front() {
        if curr == to {
            return true;
        }
        for next_u8 in 0..30u8 {
            let next_id = TerritoryId(next_u8);
            if !visited[next_u8 as usize]
                && are_adjacent(curr, next_id)
                && map.owners.get(&next_id) == Some(&owner)
            {
                visited[next_u8 as usize] = true;
                queue.push_back(next_id);
            }
        }
    }
    false
}

/// Evalúa si conquistar `target_territory` acerca al jugador `ai` a su objetivo secreto (`ObjectiveCard`).
pub fn advances_secret_objective(
    state: &CrisisState,
    map: &TerritoryStateResource,
    ai: PlayerId,
    target_territory: TerritoryId,
) -> bool {
    let Some(objectives_res) = state.world().get_resource::<PlayerObjectivesResource>() else {
        return false;
    };
    let Some(objective) = objectives_res.objectives.get(&ai) else {
        return false;
    };

    match objective {
        ObjectiveCard::ConquerContinent(continent_id) => TERRITORIES
            .get(target_territory.0 as usize)
            .map(|t| t.continent == *continent_id)
            .unwrap_or(false),
        ObjectiveCard::ConquerTwoSmallContinents => TERRITORIES
            .get(target_territory.0 as usize)
            .and_then(|t| CONTINENTS.iter().find(|c| c.id == t.continent))
            .map(|c| c.territories.len() <= 5 && !map.owns_continent(c, ai))
            .unwrap_or(false),
        ObjectiveCard::Exterminate(target_player) => {
            if *target_player == ai {
                true
            } else {
                map.owners.get(&target_territory) == Some(target_player)
            }
        }
        ObjectiveCard::ConquerTerritories(_) => true,
    }
}

/// Ejecuta `rollouts` simulaciones Monte Carlo de un asalto desde `att_armies` contra `def_armies`
/// y devuelve el valor esperado de éxito (probabilidad de conquista + supervivencia media).
fn mcts_evaluate_attack(att_armies: u32, def_armies: u32, rollouts: usize, seed: u64) -> f64 {
    let sims = rollouts.max(1);
    let mut rng = FastRng::new(seed);
    let mut total_score = 0.0;

    for _ in 0..sims {
        let mut a = att_armies;
        let mut d = def_armies;

        // Simular rondas de dados hasta conquista o quedarse con 1 ejército
        while a > 1 && d > 0 {
            let att_dice = (a - 1).min(3) as usize;
            let def_dice = d.min(3) as usize;

            let mut att_rolls = [0u8; 3];
            let mut def_rolls = [0u8; 3];
            for r in att_rolls.iter_mut().take(att_dice) {
                *r = rng.roll_d6();
            }
            for r in def_rolls.iter_mut().take(def_dice) {
                *r = rng.roll_d6();
            }
            att_rolls[..att_dice].sort_unstable_by(|x, y| y.cmp(x));
            def_rolls[..def_dice].sort_unstable_by(|x, y| y.cmp(x));

            let comps = att_dice.min(def_dice);
            for i in 0..comps {
                if att_rolls[i] > def_rolls[i] {
                    d = d.saturating_sub(1);
                } else {
                    a = a.saturating_sub(1);
                }
            }
        }

        if d == 0 {
            let remaining_ratio = (a as f64) / (att_armies.max(1) as f64);
            total_score += 1.0 + remaining_ratio;
        } else {
            let damage_ratio =
                ((def_armies.saturating_sub(d)) as f64) / (def_armies.max(1) as f64);
            total_score += damage_ratio * 0.25;
        }
    }

    total_score / (sims as f64)
}

/// Busca un trío válido de tarjetas para canjear si el jugador tiene al menos 3 tarjetas.
fn find_valid_card_exchange(state: &CrisisState, ai: PlayerId) -> Option<[usize; 3]> {
    let cards_res = state.world().get_resource::<PlayerCardsResource>()?;
    let hand = cards_res.cards.get(&ai)?;
    if hand.len() < 3 {
        return None;
    }

    for i in 0..hand.len() {
        for j in (i + 1)..hand.len() {
            for k in (j + 1)..hand.len() {
                let types = [hand[i].card_type, hand[j].card_type, hand[k].card_type];
                if is_valid_card_set(types) {
                    return Some([i, j, k]);
                }
            }
        }
    }
    None
}

/// Selecciona la mejor jugada para `ai` en Crisis/TEG según la fase actual y `difficulty`.
pub fn best_move(
    state: &CrisisState,
    ai: PlayerId,
    difficulty: AiDifficulty,
) -> Option<CrisisCommand> {
    let map = state.world().get_resource::<TerritoryStateResource>()?;
    let turn_state = state.world().get_resource::<TurnStateResource>()?;

    let mut owned_territories: Vec<TerritoryId> = map
        .owners
        .iter()
        .filter_map(|(&t_id, &owner)| if owner == ai { Some(t_id) } else { None })
        .collect();
    owned_territories.sort_by_key(|t| t.0);

    if owned_territories.is_empty() {
        return None;
    }

    match turn_state.phase {
        TurnPhase::PlaceArmies { armies_remaining } => {
            // Si tiene 5 o más tarjetas, las reglas obligan a canjear antes de colocar
            let card_count = state
                .world()
                .get_resource::<PlayerCardsResource>()
                .and_then(|c| c.cards.get(&ai))
                .map(|v| v.len())
                .unwrap_or(0);
            if card_count >= 5 {
                if let Some(indices) = find_valid_card_exchange(state, ai) {
                    return Some(CrisisCommand::ExchangeCards(ExchangeCardsCommand {
                        player: ai,
                        card_indices: indices,
                    }));
                }
            }

            if armies_remaining == 0 {
                return Some(CrisisCommand::EndPhase(EndPhaseCommand { player: ai }));
            }

            // Seleccionar el territorio propio más amenazado (menor ratio propios / vecinos enemigos)
            let mut best_territory = owned_territories[0];
            let mut lowest_ratio = f64::INFINITY;
            let mut best_obj_bonus = false;

            for &t_id in &owned_territories {
                let ratio = threat_ratio(map, ai, t_id);
                let touches_obj = difficulty == AiDifficulty::Expert
                    && adjacent_territories(t_id).into_iter().any(|adj| {
                        map.owners.get(&adj).copied() != Some(ai)
                            && advances_secret_objective(state, map, ai, adj)
                    });

                let is_better = if (ratio - lowest_ratio).abs() < 1e-9 {
                    touches_obj && !best_obj_bonus
                } else {
                    ratio < lowest_ratio
                };

                if is_better {
                    lowest_ratio = ratio;
                    best_territory = t_id;
                    best_obj_bonus = touches_obj;
                }
            }

            Some(CrisisCommand::PlaceArmies(PlaceArmiesCommand {
                player: ai,
                territory: best_territory,
                count: armies_remaining,
            }))
        }

        TurnPhase::Attack => {
            // Si ya hay un ataque declarado pendiente de lanzar dados, resolverlo
            if let Some(pending_res) = state.world().get_resource::<PendingAttackResource>() {
                if let Some(pending) = &pending_res.attack {
                    if pending.attacker == ai {
                        return Some(CrisisCommand::RollAttack(RollAttackCommand { player: ai }));
                    }
                }
            }

            let threshold = attack_ratio_threshold(difficulty);
            let rollouts = difficulty.rollouts().max(1);

            let mut best_attack: Option<(TerritoryId, TerritoryId, u8)> = None;
            let mut best_priority_obj = false;
            let mut best_score = f64::NEG_INFINITY;

            for &from in &owned_territories {
                let att_armies = map.armies.get(&from).copied().unwrap_or(0);
                if att_armies <= 1 {
                    continue;
                }

                for to in adjacent_territories(from) {
                    if map.owners.get(&to).copied() == Some(ai) {
                        continue;
                    }
                    let def_armies = map.armies.get(&to).copied().unwrap_or(0);

                    // Condición de ataque según dificultad: atacantes > defensores * threshold
                    if (att_armies as f64) <= (def_armies as f64) * threshold {
                        continue;
                    }

                    let is_obj_target = difficulty == AiDifficulty::Expert
                        && advances_secret_objective(state, map, ai, to);

                    let seed = state.id.0
                        ^ ((from.0 as u64) << 8)
                        ^ ((to.0 as u64) << 16)
                        ^ ((att_armies as u64) << 24);
                    let mcts_score = mcts_evaluate_attack(att_armies, def_armies, rollouts, seed);
                    let ratio_score = (att_armies as f64) / (def_armies.max(1) as f64);
                    let combined_score = mcts_score * 10.0 + ratio_score;

                    let should_pick = match (is_obj_target, best_priority_obj) {
                        (true, false) => true,
                        (false, true) => false,
                        _ => combined_score > best_score,
                    };

                    if should_pick {
                        best_priority_obj = is_obj_target;
                        best_score = combined_score;
                        let dice = std::cmp::min(3, att_armies - 1) as u8;
                        best_attack = Some((from, to, dice));
                    }
                }
            }

            if let Some((from, to, dice)) = best_attack {
                Some(CrisisCommand::DeclareAttack(DeclareAttackCommand {
                    player: ai,
                    from,
                    to,
                    dice,
                }))
            } else {
                Some(CrisisCommand::EndPhase(EndPhaseCommand { player: ai }))
            }
        }

        TurnPhase::Fortify => {
            if turn_state.fortified {
                return Some(CrisisCommand::EndPhase(EndPhaseCommand { player: ai }));
            }

            // Encontrar el territorio fronterizo más débil (menor threat_ratio con enemigos adyacentes)
            let border_territories: Vec<(TerritoryId, f64)> = owned_territories
                .iter()
                .copied()
                .filter_map(|t_id| {
                    let ratio = threat_ratio(map, ai, t_id);
                    if ratio.is_finite() {
                        Some((t_id, ratio))
                    } else {
                        None
                    }
                })
                .collect();

            if border_territories.is_empty() {
                return Some(CrisisCommand::EndPhase(EndPhaseCommand { player: ai }));
            }

            // Ordenar territorios fronterizos del más débil al más fuerte
            let mut sorted_borders = border_territories;
            sorted_borders.sort_by(|(ta, ra), (tb, rb)| {
                ra.partial_cmp(rb)
                    .unwrap_or(std::cmp::Ordering::Equal)
                    .then_with(|| ta.0.cmp(&tb.0))
            });

            // Buscar ejércitos excedentes para mover al territorio fronterizo más débil conectado
            for &(weakest_border, weakest_ratio) in &sorted_borders {
                // Preferir primero territorios interiores con > 1 ejército, luego territorios con mayor ratio
                let mut best_donor: Option<(TerritoryId, u32, f64)> = None;

                for &donor in &owned_territories {
                    if donor == weakest_border {
                        continue;
                    }
                    let donor_armies = map.armies.get(&donor).copied().unwrap_or(0);
                    if donor_armies <= 1 {
                        continue;
                    }
                    if !are_connected_by_owner(donor, weakest_border, ai, map) {
                        continue;
                    }

                    let donor_ratio = threat_ratio(map, ai, donor);
                    let surplus = if !donor_ratio.is_finite() {
                        // Territorio interior: todos los ejércitos salvo 1 son excedentes
                        donor_armies - 1
                    } else if donor_ratio > weakest_ratio * 2.0 && donor_armies >= 3 {
                        (donor_armies - 1) / 2
                    } else {
                        0
                    };

                    if surplus > 0 {
                        let is_better_donor = match best_donor {
                            None => true,
                            Some((_, best_surplus, best_d_ratio)) => {
                                if donor_ratio.is_infinite() && !best_d_ratio.is_infinite() {
                                    true
                                } else if !donor_ratio.is_infinite() && best_d_ratio.is_infinite() {
                                    false
                                } else {
                                    surplus > best_surplus
                                }
                            }
                        };
                        if is_better_donor {
                            best_donor = Some((donor, surplus, donor_ratio));
                        }
                    }
                }

                if let Some((from, armies, _)) = best_donor {
                    return Some(CrisisCommand::Fortify(FortifyCommand {
                        player: ai,
                        from,
                        to: weakest_border,
                        armies,
                    }));
                }
            }

            Some(CrisisCommand::EndPhase(EndPhaseCommand { player: ai }))
        }

        TurnPhase::EndTurn => Some(CrisisCommand::EndPhase(EndPhaseCommand { player: ai })),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_crisis_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn crisis_ai_reinforces_threatened_territory() {
        let mut session = new_crisis_session(SessionId(1), 42, &[P1, P2]).unwrap();

        {
            let mut map = session.world_mut().resource_mut::<TerritoryStateResource>();
            // Asignar todos los territorios inicialmente a P1 con 5 ejércitos
            for id in 0..30u8 {
                map.set_owner_and_armies(TerritoryId(id), P1, 5);
            }
            // Territorio 0 (Argentina) tiene 4 ejércitos propios y solo 2 enemigos vecinos en Chile (2) -> ratio = 4/2 = 2.0
            map.set_owner_and_armies(TerritoryId(0), P1, 4);
            map.set_owner_and_armies(TerritoryId(2), P2, 2);

            // Territorio 10 (España) tiene 2 ejércitos propios y 10 enemigos vecinos en Sahara (14) -> ratio = 2/10 = 0.2
            map.set_owner_and_armies(TerritoryId(10), P1, 2);
            map.set_owner_and_armies(TerritoryId(14), P2, 10);

            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::PlaceArmies {
                armies_remaining: 5,
            };
        }

        let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();

        match cmd {
            CrisisCommand::PlaceArmies(place) => {
                assert_eq!(place.player, P1);
                assert_eq!(
                    place.territory,
                    TerritoryId(10),
                    "Debe reforzar el territorio más amenazado (España, ratio 0.2)"
                );
                assert_eq!(place.count, 5);
            }
            other => panic!("Se esperaba PlaceArmies, se obtuvo {:?}", other),
        }
    }

    #[test]
    fn crisis_ai_attacks_when_superior() {
        let mut session = new_crisis_session(SessionId(2), 99, &[P1, P2]).unwrap();

        {
            let mut map = session.world_mut().resource_mut::<TerritoryStateResource>();
            for id in 0..30u8 {
                map.set_owner_and_armies(TerritoryId(id), P1, 1);
            }
            // Argentina (0) de P1 con 6 ejércitos frente a Brasil (1) de P2 con 2 ejércitos (6 > 2 * 1.5 = 3.0)
            map.set_owner_and_armies(TerritoryId(0), P1, 6);
            map.set_owner_and_armies(TerritoryId(1), P2, 2);

            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;
        }

        let cmd = best_move(&session, P1, AiDifficulty::Medium).unwrap();

        assert_eq!(
            cmd,
            CrisisCommand::DeclareAttack(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            })
        );

        // Si P1 solo tiene 3 ejércitos contra 2 (ratio 1.5, no > 1.5), en Medium pasa de fase,
        // pero en Expert (umbral 1.2: 3 > 2.4) sí ataca.
        {
            let mut map = session.world_mut().resource_mut::<TerritoryStateResource>();
            map.set_owner_and_armies(TerritoryId(0), P1, 3);
            map.set_owner_and_armies(TerritoryId(1), P2, 2);
        }

        let cmd_medium = best_move(&session, P1, AiDifficulty::Medium).unwrap();
        assert_eq!(
            cmd_medium,
            CrisisCommand::EndPhase(EndPhaseCommand { player: P1 })
        );

        let cmd_expert = best_move(&session, P1, AiDifficulty::Expert).unwrap();
        assert_eq!(
            cmd_expert,
            CrisisCommand::DeclareAttack(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 2,
            })
        );
    }

    #[test]
    fn crisis_ai_expert_prioritizes_secret_objective_and_fortifies() {
        let mut session = new_crisis_session(SessionId(3), 77, &[P1, P2]).unwrap();

        {
            let mut map = session.world_mut().resource_mut::<TerritoryStateResource>();
            for id in 0..30u8 {
                map.set_owner_and_armies(TerritoryId(id), P1, 1);
            }
            // P1 puede atacar desde Colombia (3, con 6 ejércitos) hacia Perú (4, América del Sur, 2 ejércitos)
            // o hacia México (5, América del Norte, 2 ejércitos).
            map.set_owner_and_armies(TerritoryId(3), P1, 6);
            map.set_owner_and_armies(TerritoryId(4), P2, 2);
            map.set_owner_and_armies(TerritoryId(5), P2, 2);

            // Objetivo secreto de P1: Conquistar América del Norte (ContinentId(1), que incluye México = 5)
            session
                .world_mut()
                .resource_mut::<PlayerObjectivesResource>()
                .objectives
                .insert(
                    P1,
                    ObjectiveCard::ConquerContinent(crate::board::CONTINENT_NORTH_AMERICA),
                );

            session.world_mut().resource_mut::<TurnStateResource>().phase = TurnPhase::Attack;
        }

        let attack_cmd = best_move(&session, P1, AiDifficulty::Expert).unwrap();
        assert_eq!(
            attack_cmd,
            CrisisCommand::DeclareAttack(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(3),
                to: TerritoryId(5),
                dice: 3,
            })
        );

        // Probar fortificación: Argentina (0) es interior con 5 ejércitos, conectada a Colombia (3, fronteriza con México 5 enemigo)
        {
            let mut map = session.world_mut().resource_mut::<TerritoryStateResource>();
            for id in 0..30u8 {
                map.set_owner_and_armies(TerritoryId(id), P1, 1);
            }
            map.set_owner_and_armies(TerritoryId(0), P1, 5); // Interior (vecinos 1, 2, 4 son de P1)
            map.set_owner_and_armies(TerritoryId(3), P1, 2); // Frontera con México (5, de P2)
            map.set_owner_and_armies(TerritoryId(5), P2, 6);

            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Fortify;
            turn_state.fortified = false;
        }

        let fortify_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            fortify_cmd,
            CrisisCommand::Fortify(FortifyCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(3),
                armies: 4,
            })
        );
    }
}
