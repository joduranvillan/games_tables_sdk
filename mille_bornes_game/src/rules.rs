use std::collections::HashSet;

use open_table_engine::prelude::*;
use open_table_macros::GameResource;

use crate::card::{Card, Hazard, Safety};
use crate::commands::{
    CoupFourreCommand, DiscardCardCommand, DrawCardCommand, PlayCardCommand, PlayDistanceCommand,
    PlayHazardCommand, PlaySafetyCommand, SetupDeckCommand,
};
use crate::deck::{build_deck, DeckResource, MAX_HAND_SIZE, TARGET_DISTANCE};
use crate::events::{
    CardDiscardedEvent, CardDrawnEvent, DistancePlayedEvent, GameOverEvent, HazardPlayedEvent,
    RemedyPlayedEvent, SafetyPlayedEvent, TripExtendedEvent,
};

#[derive(GameResource, Default)]
pub struct SpeedLimitResource {
    pub limited: HashSet<PlayerId>,
}

#[derive(GameResource, Default)]
pub struct RightOfWayResource {
    pub active: HashSet<PlayerId>,
}

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

fn ensure_resources(world: &mut BevyWorld) {
    if !world.contains_resource::<SpeedLimitResource>() {
        world.insert_resource(SpeedLimitResource::default());
    }
    if !world.contains_resource::<RightOfWayResource>() {
        world.insert_resource(RightOfWayResource::default());
    }
}

fn validate_and_play_distance(
    player: PlayerId,
    value: u32,
    world: &mut BevyWorld,
) -> Result<Vec<Box<dyn Event>>, EngineError> {
    ensure_resources(world);

    let players = world.resource::<TurnResource>().0.players().to_vec();
    let has_right_of_way = world
        .resource::<RightOfWayResource>()
        .active
        .contains(&player);
    let speed_limited = world
        .resource::<SpeedLimitResource>()
        .limited
        .contains(&player);

    let mut deck = world.resource_mut::<DeckResource>();
    let is_speed_limited =
        speed_limited || deck.hazard.get(&player).copied().flatten() == Some(Hazard::SpeedLimit);

    if is_speed_limited && !has_right_of_way && value > 50 {
        return Err(invalid(
            "límite de velocidad: solo podés jugar cartas de 25 o 50 km",
        ));
    }

    if let Some(h) = deck.hazard.get(&player).copied().flatten() {
        if h != Hazard::SpeedLimit && (!has_right_of_way || h == Hazard::OutOfGas) {
            return Err(invalid("estás detenido, jugá un remedio antes de avanzar"));
        }
    }

    if value == 200 {
        let count = deck.cards_200_played.get(&player).copied().unwrap_or(0);
        if count >= 2 {
            return Err(invalid("ya jugaste el máximo de 2 cartas de 200 km"));
        }
    }

    let current = *deck.distance.get(&player).unwrap_or(&0);
    if current + value > deck.target_distance {
        return Err(invalid("esa jugada te pasaría de la meta"));
    }

    let new_distance = current + value;
    deck.distance.insert(player, new_distance);

    if value == 200 {
        *deck.cards_200_played.entry(player).or_default() += 1;
    }

    let mut events: Vec<Box<dyn Event>> = vec![Box::new(DistancePlayedEvent {
        player,
        value,
        new_distance,
    })];

    if value == 200 {
        let all_played_2 = players
            .iter()
            .all(|p| deck.cards_200_played.get(p).copied().unwrap_or(0) >= 2);
        if all_played_2 && deck.target_distance < 1000 {
            deck.target_distance = 1000;
            events.push(Box::new(TripExtendedEvent { new_target: 1000 }));
        }
    }

    if new_distance == deck.target_distance {
        events.push(Box::new(GameOverEvent { winner: player }));
    }

    Ok(events)
}

fn validate_and_play_hazard(
    player: PlayerId,
    target: PlayerId,
    hazard: Hazard,
    world: &mut BevyWorld,
) -> Result<Vec<Box<dyn Event>>, EngineError> {
    ensure_resources(world);

    let target_row = world
        .resource::<RightOfWayResource>()
        .active
        .contains(&target);

    // Compatibilidad: RightOfWayResource bloquea todos los hazards excepto OutOfGas
    if target_row && hazard != Hazard::OutOfGas {
        return Err(invalid(
            "el objetivo tiene derecho de vía activo y es inmune a este peligro",
        ));
    }

    // Inmunidad específica por cartas de seguridad jugadas
    let has_specific_safety = {
        let deck = world.resource::<DeckResource>();
        let safeties = deck.safeties_played.get(&target);
        match hazard {
            Hazard::SpeedLimit => {
                safeties.map(|s| s.contains(&Safety::RightOfWay)).unwrap_or(false)
            }
            Hazard::OutOfGas => {
                safeties.map(|s| s.contains(&Safety::ExtraTank)).unwrap_or(false)
            }
            Hazard::FlatTire => {
                safeties.map(|s| s.contains(&Safety::PunctureProof)).unwrap_or(false)
            }
            Hazard::Accident => {
                safeties.map(|s| s.contains(&Safety::DrivingAce)).unwrap_or(false)
            }
        }
    };

    if has_specific_safety {
        return Err(invalid(
            "el objetivo tiene una carta de seguridad que lo protege de este peligro",
        ));
    }

    if hazard == Hazard::SpeedLimit {
        let limited = world
            .resource::<SpeedLimitResource>()
            .limited
            .contains(&target);
        if limited {
            return Err(invalid("el rival ya tiene un límite de velocidad activo"));
        }
        world
            .resource_mut::<SpeedLimitResource>()
            .limited
            .insert(target);
        let mut deck = world.resource_mut::<DeckResource>();
        deck.hazard.insert(target, Some(Hazard::SpeedLimit));
    } else {
        let mut deck = world.resource_mut::<DeckResource>();
        if deck.hazard.get(&target).copied().flatten().is_some() {
            return Err(invalid("el rival ya está detenido por otro peligro"));
        }
        deck.hazard.insert(target, Some(hazard));
    }

    Ok(vec![Box::new(HazardPlayedEvent {
        player,
        target,
        hazard,
    })])
}

fn validate_and_play_remedy(
    player: PlayerId,
    hazard: Hazard,
    world: &mut BevyWorld,
) -> Result<Vec<Box<dyn Event>>, EngineError> {
    ensure_resources(world);

    if hazard == Hazard::SpeedLimit {
        let limited = world
            .resource::<SpeedLimitResource>()
            .limited
            .contains(&player);
        let in_hazard = {
            let deck = world.resource::<DeckResource>();
            deck.hazard.get(&player).copied().flatten() == Some(Hazard::SpeedLimit)
        };
        if !limited && !in_hazard {
            return Err(invalid("no tenés límite de velocidad que curar"));
        }
        world
            .resource_mut::<SpeedLimitResource>()
            .limited
            .remove(&player);
        if in_hazard {
            let mut deck = world.resource_mut::<DeckResource>();
            deck.hazard.insert(player, None);
        }
    } else {
        let mut deck = world.resource_mut::<DeckResource>();
        let current_hazard = deck.hazard.get(&player).copied().flatten();
        if current_hazard != Some(hazard) {
            return Err(invalid("ese remedio no cura tu situación actual"));
        }
        deck.hazard.insert(player, None);
    }

    Ok(vec![Box::new(RemedyPlayedEvent { player, hazard })])
}

fn validate_and_play_safety(
    player: PlayerId,
    safety: Safety,
    world: &mut BevyWorld,
) -> Result<Vec<Box<dyn Event>>, EngineError> {
    ensure_resources(world);

    match safety {
        Safety::RightOfWay => {
            world
                .resource_mut::<RightOfWayResource>()
                .active
                .insert(player);
            world
                .resource_mut::<SpeedLimitResource>()
                .limited
                .remove(&player);

            let mut deck = world.resource_mut::<DeckResource>();
            deck.safeties_played.entry(player).or_default().insert(Safety::RightOfWay);
            if deck.hazard.get(&player).copied().flatten() != Some(Hazard::OutOfGas) {
                deck.hazard.insert(player, None);
            }
        }
        Safety::ExtraTank => {
            let mut deck = world.resource_mut::<DeckResource>();
            deck.safeties_played.entry(player).or_default().insert(Safety::ExtraTank);
            if deck.hazard.get(&player).copied().flatten() == Some(Hazard::OutOfGas) {
                deck.hazard.insert(player, None);
            }
        }
        Safety::PunctureProof => {
            let mut deck = world.resource_mut::<DeckResource>();
            deck.safeties_played.entry(player).or_default().insert(Safety::PunctureProof);
            if deck.hazard.get(&player).copied().flatten() == Some(Hazard::FlatTire) {
                deck.hazard.insert(player, None);
            }
        }
        Safety::DrivingAce => {
            let mut deck = world.resource_mut::<DeckResource>();
            deck.safeties_played.entry(player).or_default().insert(Safety::DrivingAce);
            if deck.hazard.get(&player).copied().flatten() == Some(Hazard::Accident) {
                deck.hazard.insert(player, None);
            }
        }
    }

    Ok(vec![Box::new(SafetyPlayedEvent { player, safety })])
}

pub fn build_mille_bornes_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<SetupDeckCommand, _>(|_cmd, world| {
        ensure_resources(world);

        let players: Vec<PlayerId> = world.resource::<TurnResource>().0.players().to_vec();

        let mut deck = build_deck();
        {
            let mut rng = world.resource_mut::<RandomResource>();
            rng.0.shuffle(&mut deck);
        }

        let mut deck_res = world.resource_mut::<DeckResource>();
        deck_res.discard_pile.clear();
        for player in &players {
            let mut hand = Vec::new();
            for _ in 0..MAX_HAND_SIZE {
                if let Some(card) = deck.pop() {
                    hand.push(card);
                }
            }
            deck_res.hands.insert(*player, hand);
            deck_res.distance.insert(*player, 0);
            deck_res.hazard.insert(*player, None);
            deck_res.cards_200_played.insert(*player, 0);
        }
        deck_res.draw_pile = deck;
        deck_res.target_distance = TARGET_DISTANCE;

        Ok(vec![])
    });

    rules.register::<DrawCardCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let mut deck = world.resource_mut::<DeckResource>();
        let hand_len = deck.hands.get(&cmd.player).map(Vec::len).unwrap_or(0);
        if hand_len >= MAX_HAND_SIZE {
            return Err(invalid("tu mano ya está llena, jugá una carta primero"));
        }

        let needs_reshuffle = deck.draw_pile.is_empty() && !deck.discard_pile.is_empty();
        let discarded_for_shuffle = if needs_reshuffle {
            std::mem::take(&mut deck.discard_pile)
        } else {
            Vec::new()
        };
        let _ = deck; // release mutable borrow before accessing RandomResource

        let shuffled = if needs_reshuffle {
            let mut d = discarded_for_shuffle;
            world.resource_mut::<RandomResource>().0.shuffle(&mut d);
            d
        } else {
            Vec::new()
        };

        let mut deck = world.resource_mut::<DeckResource>();
        if needs_reshuffle {
            deck.draw_pile = shuffled;
        }

        let card = deck
            .draw_pile
            .pop()
            .ok_or_else(|| invalid("no quedan cartas en el mazo"))?;
        deck.hands.entry(cmd.player).or_default().push(card);

        Ok(vec![Box::new(CardDrawnEvent {
            player: cmd.player,
            card,
        }) as Box<dyn Event>])
    });

    rules.register::<PlayCardCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let opponent = world.resource::<TurnResource>().0.peek_next();
        let card = {
            let deck = world.resource::<DeckResource>();
            let hand = deck
                .hands
                .get(&cmd.player)
                .ok_or_else(|| invalid("no tenés mano en esta partida"))?;
            if cmd.card_index >= hand.len() {
                return Err(invalid("ese índice de carta no existe en tu mano"));
            }
            hand[cmd.card_index]
        };

        let is_safety = matches!(card, Card::Safety(_) | Card::RightOfWay);
        let events = match card {
            Card::Distance(value) => validate_and_play_distance(cmd.player, value, world)?,
            Card::Hazard(hazard) => validate_and_play_hazard(cmd.player, opponent, hazard, world)?,
            Card::Remedy(hazard) => validate_and_play_remedy(cmd.player, hazard, world)?,
            Card::Safety(safety) => validate_and_play_safety(cmd.player, safety, world)?,
            Card::RightOfWay => validate_and_play_safety(cmd.player, Safety::RightOfWay, world)?,
        };

        world
            .resource_mut::<DeckResource>()
            .hands
            .get_mut(&cmd.player)
            .unwrap()
            .remove(cmd.card_index);

        // Jugar una carta de seguridad otorga turno extra (no avanza el turno)
        if !is_safety {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<PlayDistanceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        let events = validate_and_play_distance(cmd.player, cmd.distance, world)?;
        world.resource_mut::<TurnResource>().0.advance();
        Ok(events)
    });

    rules.register::<PlayHazardCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        let events = validate_and_play_hazard(cmd.player, cmd.target, cmd.hazard, world)?;
        world.resource_mut::<TurnResource>().0.advance();
        Ok(events)
    });

    rules.register::<PlaySafetyCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        let events = validate_and_play_safety(cmd.player, cmd.safety, world)?;
        let mut deck = world.resource_mut::<DeckResource>();
        if let Some(hand) = deck.hands.get_mut(&cmd.player) {
            if let Some(pos) = hand.iter().position(|&c| match c {
                Card::Safety(s) if s == cmd.safety => true,
                Card::RightOfWay if cmd.safety == Safety::RightOfWay => true,
                _ => false,
            }) {
                hand.remove(pos);
            }
        }
        // Turno extra por jugar carta de seguridad
        Ok(events)
    });

    rules.register::<DiscardCardCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let mut deck = world.resource_mut::<DeckResource>();
        let hand = deck
            .hands
            .get_mut(&cmd.player)
            .ok_or_else(|| invalid("no tenés mano en esta partida"))?;
        if cmd.card_index >= hand.len() {
            return Err(invalid("ese índice de carta no existe en tu mano"));
        }

        let card = hand.remove(cmd.card_index);
        deck.discard_pile.push(card);

        let _ = deck;
        world.resource_mut::<TurnResource>().0.advance();

        Ok(vec![Box::new(CardDiscardedEvent {
            player: cmd.player,
            card,
        }) as Box<dyn Event>])
    });

    rules.register::<CoupFourreCommand, _>(|cmd, world| {
        ensure_resources(world);

        let opponent = world
            .resource::<TurnResource>()
            .0
            .players()
            .iter()
            .copied()
            .find(|&p| p != cmd.player)
            .ok_or_else(|| invalid("no hay rival"))?;

        let mut deck = world.resource_mut::<DeckResource>();

        let hazard = deck
            .hazard
            .get(&cmd.player)
            .copied()
            .flatten()
            .ok_or_else(|| invalid("no tenés ningún peligro para responder con coup fourré"))?;

        let matching_safety = match hazard {
            Hazard::SpeedLimit => Safety::RightOfWay,
            Hazard::OutOfGas => Safety::ExtraTank,
            Hazard::FlatTire => Safety::PunctureProof,
            Hazard::Accident => Safety::DrivingAce,
        };

        let hand = deck
            .hands
            .get_mut(&cmd.player)
            .ok_or_else(|| invalid("no tenés mano en esta partida"))?;

        let safety_pos = hand.iter().position(|&c| match c {
            Card::Safety(s) if s == matching_safety => true,
            Card::RightOfWay if matching_safety == Safety::RightOfWay => true,
            _ => false,
        });

        let mut events: Vec<Box<dyn Event>> = Vec::new();

        if let Some(pos) = safety_pos {
            let card = hand.remove(pos);
            let s = match card {
                Card::Safety(sf) => sf,
                _ => Safety::RightOfWay,
            };
            deck.safeties_played.entry(cmd.player).or_default().insert(s);
            deck.hazard.insert(cmd.player, None);
            deck.hazard.insert(opponent, Some(hazard));

            // Bono de +100 km por Coup Fourré
            let current_dist = *deck.distance.get(&cmd.player).unwrap_or(&0);
            let new_dist = (current_dist + 100).min(deck.target_distance);
            deck.distance.insert(cmd.player, new_dist);

            events.push(Box::new(SafetyPlayedEvent {
                player: cmd.player,
                safety: s,
            }));
            events.push(Box::new(DistancePlayedEvent {
                player: cmd.player,
                value: 100,
                new_distance: new_dist,
            }));
            events.push(Box::new(HazardPlayedEvent {
                player: cmd.player,
                target: opponent,
                hazard,
            }));

            if new_dist == deck.target_distance {
                events.push(Box::new(GameOverEvent { winner: cmd.player }));
            }

            let _ = deck;
            if s == Safety::RightOfWay {
                world
                    .resource_mut::<RightOfWayResource>()
                    .active
                    .insert(cmd.player);
            }
            if hazard == Hazard::SpeedLimit {
                let mut speed_res = world.resource_mut::<SpeedLimitResource>();
                speed_res.limited.remove(&cmd.player);
                speed_res.limited.insert(opponent);
            }
        } else {
            let remedy_pos = hand
                .iter()
                .position(|&c| c == Card::Remedy(hazard))
                .ok_or_else(|| invalid("no tenés la carta de seguridad o el remedio correspondiente en la mano"))?;

            hand.remove(remedy_pos);
            deck.hazard.insert(cmd.player, None);
            deck.hazard.insert(opponent, Some(hazard));

            events.push(Box::new(RemedyPlayedEvent {
                player: cmd.player,
                hazard,
            }));
            events.push(Box::new(HazardPlayedEvent {
                player: cmd.player,
                target: opponent,
                hazard,
            }));

            let _ = deck;
            if hazard == Hazard::SpeedLimit {
                let mut speed_res = world.resource_mut::<SpeedLimitResource>();
                speed_res.limited.remove(&cmd.player);
                speed_res.limited.insert(opponent);
            }
        }

        Ok(events)
    });

    rules
}
