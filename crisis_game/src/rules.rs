use open_table_engine::prelude::*;
use std::collections::VecDeque;

use crate::board::{
    are_adjacent, check_continent_bonus, check_objective, TerritoryId, CONTINENTS,
};
use crate::commands::{
    DeclareAttackCommand, EndPhaseCommand, ExchangeCardsCommand, FortifyCommand,
    PlaceArmiesCommand, RollAttackCommand,
};
use crate::events::{
    ArmiesPlacedEvent, AttackDeclaredEvent, AttackResolvedEvent, CardType, CardsExchangedEvent,
    FortifiedEvent, PhaseChangedEvent, PlayerEliminatedEvent, TegGameOverEvent,
    TerritoryConqueredEvent,
};
use crate::resources::{
    EliminatedPlayersResource, ExchangeCountResource, PendingAttack,
    PendingAttackResource, PlayerCardsResource, PlayerObjectivesResource, PlayersResource,
    TerritoryStateResource, TurnPhase, TurnStateResource,
};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

pub fn is_valid_card_set(types: [CardType; 3]) -> bool {
    let has_wild = types.contains(&CardType::Wild);
    if has_wild {
        return true;
    }
    let (a, b, c) = (types[0], types[1], types[2]);
    let three_same = a == b && b == c;
    let one_of_each = a != b && b != c && a != c;
    three_same || one_of_each
}

fn are_connected_by_owner(
    from: TerritoryId,
    to: TerritoryId,
    owner: PlayerId,
    territory_state: &TerritoryStateResource,
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
        for next_id_u8 in 0..30u8 {
            let next_id = TerritoryId(next_id_u8);
            if !visited[next_id.0 as usize]
                && are_adjacent(curr, next_id)
                && territory_state.owners.get(&next_id) == Some(&owner)
            {
                visited[next_id.0 as usize] = true;
                queue.push_back(next_id);
            }
        }
    }
    false
}

pub fn build_crisis_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<PlaceArmiesCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let player_cards = world.resource::<PlayerCardsResource>();
        let card_count = player_cards.cards.get(&cmd.player).map(|c| c.len()).unwrap_or(0);
        if card_count >= 5 {
            return Err(invalid("debés canjear tarjetas antes de colocar ejércitos (tenés 5 o más tarjetas)"));
        }

        let armies_remaining = match world.resource::<TurnStateResource>().phase {
            TurnPhase::PlaceArmies { armies_remaining } => armies_remaining,
            _ => return Err(invalid("no estás en la fase de colocar ejércitos")),
        };

        let territory_state = world.resource::<TerritoryStateResource>();
        let owner = territory_state.owners.get(&cmd.territory).copied();
        if owner != Some(cmd.player) {
            return Err(invalid("el territorio objetivo no te pertenece"));
        }

        if !(1..=armies_remaining).contains(&cmd.count) {
            return Err(invalid("cantidad de ejércitos a colocar inválida"));
        }

        let new_remaining = armies_remaining - cmd.count;

        let mut territory_state = world.resource_mut::<TerritoryStateResource>();
        *territory_state.armies.entry(cmd.territory).or_insert(0) += cmd.count;

        let mut events: Vec<Box<dyn Event>> = Vec::new();

        events.push(Box::new(ArmiesPlacedEvent {
            player: cmd.player,
            territory: cmd.territory,
            count: cmd.count,
            armies_remaining: new_remaining,
        }));

        let mut turn_state = world.resource_mut::<TurnStateResource>();
        if new_remaining == 0 {
            turn_state.phase = TurnPhase::Attack;
            events.push(Box::new(PhaseChangedEvent {
                player: cmd.player,
                new_phase: "Attack".to_string(),
            }));
        } else {
            turn_state.phase = TurnPhase::PlaceArmies {
                armies_remaining: new_remaining,
            };
        }

        Ok(events)
    });

    rules.register::<DeclareAttackCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let turn_state = world.resource::<TurnStateResource>();
        if turn_state.phase != TurnPhase::Attack {
            return Err(invalid("no estás en la fase de ataque"));
        }

        let territory_state = world.resource::<TerritoryStateResource>();

        let from_owner = territory_state.owners.get(&cmd.from).copied();
        if from_owner != Some(cmd.player) {
            return Err(invalid("el territorio de origen no te pertenece"));
        }

        if !are_adjacent(cmd.from, cmd.to) {
            return Err(invalid("el territorio de destino no es adyacente al de origen"));
        }

        let to_owner = territory_state.owners.get(&cmd.to).copied();
        if to_owner == Some(cmd.player) {
            return Err(invalid("no podés atacar un territorio que ya te pertenece"));
        }

        let armies_from = territory_state.armies.get(&cmd.from).copied().unwrap_or(0);
        if armies_from <= 1 {
            return Err(invalid("necesitás más de 1 ejército para atacar"));
        }

        let max_dice = std::cmp::min(3, armies_from - 1) as u8;
        if !(1..=max_dice).contains(&cmd.dice) {
            return Err(invalid(format!(
                "cantidad de dados inválida ({}, max: {})",
                cmd.dice, max_dice
            )));
        }

        let mut pending_attack = world.resource_mut::<PendingAttackResource>();
        pending_attack.attack = Some(PendingAttack {
            attacker: cmd.player,
            from: cmd.from,
            to: cmd.to,
            dice: cmd.dice,
        });

        Ok(vec![Box::new(AttackDeclaredEvent {
            attacker: cmd.player,
            from: cmd.from,
            to: cmd.to,
            dice: cmd.dice,
        })])
    });

    rules.register::<RollAttackCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let turn_state = world.resource::<TurnStateResource>();
        if turn_state.phase != TurnPhase::Attack {
            return Err(invalid("no estás en la fase de ataque"));
        }

        let attack = world
            .resource::<PendingAttackResource>()
            .attack
            .clone()
            .ok_or_else(|| invalid("no hay ataque pendiente"))?;

        if attack.attacker != cmd.player {
            return Err(invalid("el ataque pendiente pertenece a otro jugador"));
        }

        let (attacker_rolls, defender_rolls, defender_id) = {
            let defender_id = world
                .resource::<TerritoryStateResource>()
                .owners
                .get(&attack.to)
                .copied()
                .unwrap();
            let def_armies = world
                .resource::<TerritoryStateResource>()
                .armies
                .get(&attack.to)
                .copied()
                .unwrap_or(0);
            let defender_dice_count = std::cmp::min(3, def_armies) as u8;

            let mut random_res = world.resource_mut::<RandomResource>();
            let mut att_rolls = Vec::new();
            for _ in 0..attack.dice {
                att_rolls.push(random_res.0.roll_die(6));
            }
            let mut def_rolls = Vec::new();
            for _ in 0..defender_dice_count {
                def_rolls.push(random_res.0.roll_die(6));
            }

            att_rolls.sort_unstable_by(|a, b| b.cmp(a));
            def_rolls.sort_unstable_by(|a, b| b.cmp(a));

            (att_rolls, def_rolls, defender_id)
        };

        let mut attacker_losses = 0;
        let mut defender_losses = 0;
        let comparisons = std::cmp::min(attacker_rolls.len(), defender_rolls.len());
        for i in 0..comparisons {
            if attacker_rolls[i] > defender_rolls[i] {
                defender_losses += 1;
            } else {
                attacker_losses += 1;
            }
        }

        let territory_conquered = {
            let mut territory_state = world.resource_mut::<TerritoryStateResource>();
            let att_armies = territory_state.armies.get_mut(&attack.from).unwrap();
            *att_armies = att_armies.saturating_sub(attacker_losses);

            let def_armies = territory_state.armies.get_mut(&attack.to).unwrap();
            if *def_armies <= defender_losses {
                *def_armies = 0;
                true
            } else {
                *def_armies -= defender_losses;
                false
            }
        };

        let mut events: Vec<Box<dyn Event>> = Vec::new();

        events.push(Box::new(AttackResolvedEvent {
            attacker: cmd.player,
            defender: defender_id,
            from: attack.from,
            to: attack.to,
            attacker_rolls: attacker_rolls.clone(),
            defender_rolls: defender_rolls.clone(),
            attacker_losses,
            defender_losses,
            territory_conquered,
        }));

        if territory_conquered {
            let (rem_from_armies, remaining_def_territories) = {
                let mut territory_state = world.resource_mut::<TerritoryStateResource>();
                territory_state.owners.insert(attack.to, cmd.player);
                let from_armies = territory_state.armies.get_mut(&attack.from).unwrap();
                *from_armies = from_armies.saturating_sub(attack.dice as u32);
                let rem_from_armies = *from_armies;
                territory_state.armies.insert(attack.to, attack.dice as u32);

                let remaining_def_territories = territory_state
                    .owners
                    .values()
                    .filter(|&&o| o == defender_id)
                    .count();
                (rem_from_armies, remaining_def_territories)
            };

            events.push(Box::new(TerritoryConqueredEvent {
                player: cmd.player,
                territory: attack.to,
                from: attack.from,
                from_armies: rem_from_armies,
                to_armies: attack.dice as u32,
                card_drawn: None,
            }));

            if remaining_def_territories == 0 {
                let mut eliminated_res = world.resource_mut::<EliminatedPlayersResource>();
                eliminated_res.eliminate(defender_id, cmd.player);
                events.push(Box::new(PlayerEliminatedEvent {
                    player: defender_id,
                    by: cmd.player,
                }));
            }

            let player_obj = world
                .resource::<PlayerObjectivesResource>()
                .objectives
                .get(&cmd.player)
                .cloned();

            if let Some(obj) = player_obj {
                let territory_state = world.resource::<TerritoryStateResource>();
                let players = world.resource::<PlayersResource>().players.clone();
                let eliminated = world.resource::<EliminatedPlayersResource>();

                if check_objective(&obj, territory_state, &players, eliminated, cmd.player) {
                    let mut game_over = world.resource_mut::<GameOverResource>();
                    game_over.0 = true;

                    if let Some(mut winner) = world.get_resource_mut::<WinnerResource>() {
                        winner.0 = Some(cmd.player);
                    } else {
                        world.insert_resource(WinnerResource(Some(cmd.player)));
                    }

                    events.push(Box::new(TegGameOverEvent {
                        winner: cmd.player,
                        objective: format!("{:?}", obj),
                    }));
                }
            }
        }

        let mut pending_attack = world.resource_mut::<PendingAttackResource>();
        pending_attack.attack = None;

        Ok(events)
    });

    rules.register::<EndPhaseCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let current_phase = world.resource::<TurnStateResource>().phase.clone();

        match current_phase {
            TurnPhase::PlaceArmies { armies_remaining } => {
                if armies_remaining > 0 {
                    return Err(invalid("debe colocar todos los ejércitos"));
                }
                let mut turn_state = world.resource_mut::<TurnStateResource>();
                turn_state.phase = TurnPhase::Attack;
                Ok(vec![Box::new(PhaseChangedEvent {
                    player: cmd.player,
                    new_phase: "Attack".to_string(),
                })])
            }
            TurnPhase::Attack => {
                let mut turn_state = world.resource_mut::<TurnStateResource>();
                turn_state.phase = TurnPhase::Fortify;
                Ok(vec![Box::new(PhaseChangedEvent {
                    player: cmd.player,
                    new_phase: "Fortify".to_string(),
                })])
            }
            TurnPhase::Fortify | TurnPhase::EndTurn => {
                let next_player = {
                    let eliminated = world.resource::<EliminatedPlayersResource>().eliminated.clone();
                    let mut turn_res = world.resource_mut::<TurnResource>();
                    let mut next_p = turn_res.0.advance();
                    while eliminated.contains(&next_p) {
                        next_p = turn_res.0.advance();
                    }
                    next_p
                };

                let territory_state = world.resource::<TerritoryStateResource>();

                let count_territories = territory_state
                    .owners
                    .values()
                    .filter(|&&o| o == next_player)
                    .count() as u32;
                let base_refuerzos = std::cmp::max(3, count_territories / 3);

                let continent_bonus = check_continent_bonus(territory_state, next_player, CONTINENTS);

                let refuerzos = base_refuerzos + continent_bonus;

                let mut turn_state = world.resource_mut::<TurnStateResource>();
                turn_state.phase = TurnPhase::PlaceArmies {
                    armies_remaining: refuerzos,
                };
                turn_state.fortified = false;

                Ok(vec![Box::new(PhaseChangedEvent {
                    player: next_player,
                    new_phase: "PlaceArmies".to_string(),
                })])
            }
        }
    });

    rules.register::<FortifyCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let turn_state = world.resource::<TurnStateResource>();
        if turn_state.phase != TurnPhase::Fortify {
            return Err(invalid("no estás en la fase de fortificación"));
        }

        if turn_state.fortified {
            return Err(invalid("ya fortificaste en este turno"));
        }

        let territory_state = world.resource::<TerritoryStateResource>();

        let from_owner = territory_state.owners.get(&cmd.from).copied();
        if from_owner != Some(cmd.player) {
            return Err(invalid("el territorio de origen no te pertenece"));
        }

        let to_owner = territory_state.owners.get(&cmd.to).copied();
        if to_owner != Some(cmd.player) {
            return Err(invalid("el territorio de destino no te pertenece"));
        }

        if !are_connected_by_owner(cmd.from, cmd.to, cmd.player, territory_state) {
            return Err(invalid("los territorios no están conectados por territorios propios"));
        }

        let armies_from = territory_state.armies.get(&cmd.from).copied().unwrap_or(0);
        if cmd.armies == 0 || cmd.armies > armies_from.saturating_sub(1) {
            return Err(invalid("cantidad de ejércitos a mover inválida"));
        }

        let mut territory_state = world.resource_mut::<TerritoryStateResource>();
        territory_state.armies.entry(cmd.from).and_modify(|a| *a -= cmd.armies);
        territory_state.armies.entry(cmd.to).and_modify(|a| *a += cmd.armies);

        let mut turn_state = world.resource_mut::<TurnStateResource>();
        turn_state.fortified = true;

        Ok(vec![Box::new(FortifiedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            armies: cmd.armies,
        })])
    });

    rules.register::<ExchangeCardsCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let turn_state = world.resource::<TurnStateResource>();
        let armies_remaining = match turn_state.phase {
            TurnPhase::PlaceArmies { armies_remaining } => armies_remaining,
            _ => return Err(invalid("solo podés canjear tarjetas en la fase de colocación de ejércitos")),
        };

        let mut idxs = cmd.card_indices;
        if idxs[0] == idxs[1] || idxs[1] == idxs[2] || idxs[0] == idxs[2] {
            return Err(invalid("debes seleccionar 3 tarjetas distintas"));
        }

        let mut player_cards_res = world.resource_mut::<PlayerCardsResource>();
        let cards = player_cards_res.cards.entry(cmd.player).or_default();

        if idxs[0] >= cards.len() || idxs[1] >= cards.len() || idxs[2] >= cards.len() {
            return Err(invalid("índices de tarjetas inválidos"));
        }

        let selected_types = [
            cards[idxs[0]].card_type,
            cards[idxs[1]].card_type,
            cards[idxs[2]].card_type,
        ];

        if !is_valid_card_set(selected_types) {
            return Err(invalid("combinación de tarjetas inválida"));
        }

        idxs.sort_unstable_by(|a, b| b.cmp(a));
        for idx in idxs {
            cards.remove(idx);
        }

        let mut exchange_count = world.resource_mut::<ExchangeCountResource>();
        let bonus_armies = exchange_count.next_bonus();

        let new_remaining = armies_remaining + bonus_armies;
        let mut turn_state = world.resource_mut::<TurnStateResource>();
        turn_state.phase = TurnPhase::PlaceArmies {
            armies_remaining: new_remaining,
        };

        Ok(vec![Box::new(CardsExchangedEvent {
            player: cmd.player,
            armies_gained: bonus_armies,
        })])
    });

    rules
}
