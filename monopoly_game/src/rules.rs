use std::collections::HashSet;

use open_table_engine::prelude::*;

use crate::board::{Space, GO_BONUS, GO_TO_JAIL_SPACE, JAIL_SPACE};
use crate::commands::{
    AuctionBidCommand, BuyPropertyCommand, PayJailFeeCommand, RollAndMoveCommand,
};
use crate::events::{
    AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent, GameOverEvent, JailedEvent,
    PlayerMovedEvent, PropertyPurchasedEvent, RailroadRentPaidEvent, RentPaidEvent,
    UtilityRentPaidEvent,
};
use crate::resources::{
    AuctionResource, AuctionState, BoardResource, JailResource, PendingDecision,
    PendingPurchaseResource, PlayersResource,
};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

fn advance_turn_skip_bankrupt(world: &mut BevyWorld) {
    for _ in 0..10 {
        let next = world.resource_mut::<TurnResource>().0.advance();
        let is_bankrupt = world.resource::<PlayersResource>().bankrupt.contains(&next);
        if !is_bankrupt {
            break;
        }
    }
}

fn handle_bankruptcy(
    player: PlayerId,
    creditor: Option<PlayerId>,
    world: &mut BevyWorld,
    events: &mut Vec<Box<dyn Event>>,
) {
    events.push(Box::new(BankruptcyEvent { player }));

    let mut players = world.resource_mut::<PlayersResource>();
    players.bankrupt.insert(player);

    let player_props: Vec<usize> = players
        .properties
        .iter()
        .filter(|(_, &owner)| owner == player)
        .map(|(&space, _)| space)
        .collect();

    for space in player_props {
        if let Some(creditor_player) = creditor {
            players.properties.insert(space, creditor_player);
        } else {
            players.properties.remove(&space);
        }
    }
    let _ = players;

    let all_players = world.resource::<TurnResource>().0.players().to_vec();
    let players_res = world.resource::<PlayersResource>();
    let active_players: Vec<PlayerId> = all_players
        .into_iter()
        .filter(|p| !players_res.bankrupt.contains(p))
        .collect();

    if active_players.len() == 1 {
        events.push(Box::new(GameOverEvent {
            winner: active_players[0],
        }));
    }
}

pub fn build_monopoly_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<PayJailFeeCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let is_jailed = world
            .resource::<JailResource>()
            .jailed
            .contains_key(&cmd.player);
        if !is_jailed {
            return Err(invalid("no estás en la cárcel"));
        }

        let mut players = world.resource_mut::<PlayersResource>();
        let money = *players.money.get(&cmd.player).unwrap_or(&0);
        if money < 50 {
            return Err(invalid("no tenés suficiente dinero para pagar la fianza"));
        }
        players.money.insert(cmd.player, money - 50);
        let _ = players;

        world
            .resource_mut::<JailResource>()
            .jailed
            .remove(&cmd.player);

        Ok(vec![])
    });

    rules.register::<AuctionBidCommand, _>(|cmd, world| {
        let auction_active = world.resource::<AuctionResource>().state.is_some();
        if !auction_active {
            return Err(invalid("no hay ninguna subasta activa"));
        }

        if cmd.amount > 0 {
            let player_money = world
                .resource::<PlayersResource>()
                .money
                .get(&cmd.player)
                .copied()
                .unwrap_or(0);
            if player_money < cmd.amount as i64 {
                return Err(invalid(
                    "no tenés suficiente dinero para realizar esta puja",
                ));
            }

            let mut auction = world.resource_mut::<AuctionResource>();
            let state = auction.state.as_mut().unwrap();
            if cmd.amount <= state.current_bid {
                return Err(invalid("la puja debe ser mayor a la puja actual"));
            }
            state.current_bid = cmd.amount;
            state.highest_bidder = Some(cmd.player);
        } else {
            let mut auction = world.resource_mut::<AuctionResource>();
            let state = auction.state.as_mut().unwrap();
            state.passed.insert(cmd.player);
        }

        let all_players = world.resource::<TurnResource>().0.players().to_vec();
        let bankrupt = world.resource::<PlayersResource>().bankrupt.clone();
        let active_players: Vec<PlayerId> = all_players
            .into_iter()
            .filter(|p| !bankrupt.contains(p))
            .collect();

        let state = world.resource::<AuctionResource>().state.as_ref().unwrap();
        let active_bidders: Vec<PlayerId> = active_players
            .iter()
            .copied()
            .filter(|p| !state.passed.contains(p))
            .collect();

        let mut events: Vec<Box<dyn Event>> = Vec::new();

        if active_bidders.len() <= 1 {
            let state = world
                .resource_mut::<AuctionResource>()
                .state
                .take()
                .unwrap();
            if let Some(winner) = state.highest_bidder {
                let mut players = world.resource_mut::<PlayersResource>();
                let money = *players.money.get(&winner).unwrap_or(&0);
                players
                    .money
                    .insert(winner, money - state.current_bid as i64);
                players.properties.insert(state.space, winner);
                let _ = players;

                events.push(Box::new(AuctionWonEvent {
                    player: winner,
                    space: state.space,
                    price: state.current_bid,
                }));
            }
            advance_turn_skip_bankrupt(world);
        }

        Ok(events)
    });

    rules.register::<RollAndMoveCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        if world
            .resource::<PlayersResource>()
            .bankrupt
            .contains(&cmd.player)
        {
            return Err(invalid("estás en quiebra y no podés jugar"));
        }
        if world
            .resource::<PendingPurchaseResource>()
            .pending
            .contains_key(&cmd.player)
        {
            return Err(invalid(
                "tenés una decisión de compra pendiente, resolvela antes de tirar",
            ));
        }
        if world.resource::<AuctionResource>().state.is_some() {
            return Err(invalid("hay una subasta activa en curso"));
        }

        let (d1, d2) = {
            let mut rng = world.resource_mut::<RandomResource>();
            (rng.0.roll_die(6), rng.0.roll_die(6))
        };
        let roll = d1 + d2;
        let is_doubles = d1 == d2;

        let is_jailed = world
            .resource::<JailResource>()
            .jailed
            .contains_key(&cmd.player);

        let mut events: Vec<Box<dyn Event>> = Vec::new();

        if is_jailed {
            if is_doubles {
                world
                    .resource_mut::<JailResource>()
                    .jailed
                    .remove(&cmd.player);
            } else {
                let attempts = *world
                    .resource::<JailResource>()
                    .jailed
                    .get(&cmd.player)
                    .unwrap();
                if attempts <= 1 {
                    world
                        .resource_mut::<JailResource>()
                        .jailed
                        .remove(&cmd.player);
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = *players.money.get(&cmd.player).unwrap_or(&0) - 50;
                    players.money.insert(cmd.player, money);
                    let _ = players;

                    if money < 0 {
                        handle_bankruptcy(cmd.player, None, world, &mut events);
                        advance_turn_skip_bankrupt(world);
                        return Ok(events);
                    }
                } else {
                    world
                        .resource_mut::<JailResource>()
                        .jailed
                        .insert(cmd.player, attempts - 1);
                    events.push(Box::new(PlayerMovedEvent {
                        player: cmd.player,
                        roll,
                        d1,
                        d2,
                        is_doubles: false,
                        new_position: JAIL_SPACE,
                        passed_go: false,
                    }));
                    advance_turn_skip_bankrupt(world);
                    return Ok(events);
                }
            }
        }

        let board_spaces = world.resource::<BoardResource>().spaces.clone();
        let board_size = board_spaces.len();

        let mut players = world.resource_mut::<PlayersResource>();
        let old_pos = *players.position.get(&cmd.player).unwrap_or(&0);
        let raw = old_pos + roll as usize;
        let mut new_pos = raw % board_size;
        let passed_go = raw >= board_size;

        let mut money = *players.money.get(&cmd.player).unwrap_or(&0);
        if passed_go {
            money += GO_BONUS;
        }

        let mut jailed = false;
        if new_pos == GO_TO_JAIL_SPACE {
            new_pos = JAIL_SPACE;
            jailed = true;
        }

        players.position.insert(cmd.player, new_pos);
        players.money.insert(cmd.player, money);
        let _ = players;

        if jailed {
            world
                .resource_mut::<JailResource>()
                .jailed
                .insert(cmd.player, 3);
        }

        events.push(Box::new(PlayerMovedEvent {
            player: cmd.player,
            roll,
            d1,
            d2,
            is_doubles,
            new_position: new_pos,
            passed_go,
        }));

        if jailed {
            events.push(Box::new(JailedEvent { player: cmd.player }));
        }

        let mut awaiting_decision = false;

        if !jailed {
            let space = board_spaces[new_pos].clone();
            match space {
                Space::Property {
                    ref group, rent, ..
                } => {
                    let owner = world
                        .resource::<PlayersResource>()
                        .properties
                        .get(&new_pos)
                        .copied();
                    match owner {
                        None => {
                            awaiting_decision = true;
                            world
                                .resource_mut::<PendingPurchaseResource>()
                                .pending
                                .insert(
                                    cmd.player,
                                    PendingDecision {
                                        space: new_pos,
                                        is_doubles,
                                    },
                                );
                        }
                        Some(owner) if owner == cmd.player => {}
                        Some(owner) => {
                            let mut players = world.resource_mut::<PlayersResource>();
                            let is_full_group =
                                players.owns_full_group(&board_spaces, owner, group);
                            let actual_rent = if is_full_group { rent * 2 } else { rent };

                            let payer_money = players.money.get(&cmd.player).copied().unwrap_or(0)
                                - actual_rent as i64;
                            players.money.insert(cmd.player, payer_money);
                            *players.money.entry(owner).or_insert(0) += actual_rent as i64;
                            let _ = players;

                            events.push(Box::new(RentPaidEvent {
                                payer: cmd.player,
                                owner,
                                space: new_pos,
                                amount: actual_rent,
                            }));

                            if payer_money < 0 {
                                handle_bankruptcy(cmd.player, Some(owner), world, &mut events);
                            }
                        }
                    }
                }
                Space::Utility { .. } => {
                    let owner = world
                        .resource::<PlayersResource>()
                        .properties
                        .get(&new_pos)
                        .copied();
                    match owner {
                        None => {
                            awaiting_decision = true;
                            world
                                .resource_mut::<PendingPurchaseResource>()
                                .pending
                                .insert(
                                    cmd.player,
                                    PendingDecision {
                                        space: new_pos,
                                        is_doubles,
                                    },
                                );
                        }
                        Some(owner) if owner == cmd.player => {}
                        Some(owner) => {
                            let count = world
                                .resource::<PlayersResource>()
                                .count_utilities(&board_spaces, owner);
                            let multiplier = if count >= 2 { 10 } else { 4 };
                            let actual_rent = multiplier * roll;

                            let mut players = world.resource_mut::<PlayersResource>();
                            let payer_money = players.money.get(&cmd.player).copied().unwrap_or(0)
                                - actual_rent as i64;
                            players.money.insert(cmd.player, payer_money);
                            *players.money.entry(owner).or_insert(0) += actual_rent as i64;
                            let _ = players;

                            events.push(Box::new(UtilityRentPaidEvent {
                                player: cmd.player,
                                owner,
                                multiplier,
                                dice_total: roll,
                                amount: actual_rent,
                            }));

                            if payer_money < 0 {
                                handle_bankruptcy(cmd.player, Some(owner), world, &mut events);
                            }
                        }
                    }
                }
                Space::Railroad { .. } => {
                    let owner = world
                        .resource::<PlayersResource>()
                        .properties
                        .get(&new_pos)
                        .copied();
                    match owner {
                        None => {
                            awaiting_decision = true;
                            world
                                .resource_mut::<PendingPurchaseResource>()
                                .pending
                                .insert(
                                    cmd.player,
                                    PendingDecision {
                                        space: new_pos,
                                        is_doubles,
                                    },
                                );
                        }
                        Some(owner) if owner == cmd.player => {}
                        Some(owner) => {
                            let count = world
                                .resource::<PlayersResource>()
                                .count_railroads(&board_spaces, owner);
                            let actual_rent = match count {
                                1 => 25,
                                2 => 50,
                                3 => 100,
                                _ => 200,
                            };

                            let mut players = world.resource_mut::<PlayersResource>();
                            let payer_money = players.money.get(&cmd.player).copied().unwrap_or(0)
                                - actual_rent as i64;
                            players.money.insert(cmd.player, payer_money);
                            *players.money.entry(owner).or_insert(0) += actual_rent as i64;
                            let _ = players;

                            events.push(Box::new(RailroadRentPaidEvent {
                                player: cmd.player,
                                owner,
                                railroads_owned: count,
                                amount: actual_rent,
                            }));

                            if payer_money < 0 {
                                handle_bankruptcy(cmd.player, Some(owner), world, &mut events);
                            }
                        }
                    }
                }
                _ => {}
            }
        }

        let is_bankrupt = world
            .resource::<PlayersResource>()
            .bankrupt
            .contains(&cmd.player);
        if !awaiting_decision && (!is_doubles || is_bankrupt) {
            advance_turn_skip_bankrupt(world);
        }

        Ok(events)
    });

    rules.register::<BuyPropertyCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let pending_decision = *world
            .resource::<PendingPurchaseResource>()
            .pending
            .get(&cmd.player)
            .ok_or_else(|| invalid("no tenés ninguna decisión de compra pendiente"))?;

        let space = pending_decision.space;
        let is_doubles = pending_decision.is_doubles;

        let mut events: Vec<Box<dyn Event>> = Vec::new();

        if cmd.buy {
            let price = match &world.resource::<BoardResource>().spaces[space] {
                Space::Property { price, .. } => *price,
                Space::Utility { price, .. } => *price,
                Space::Railroad { price, .. } => *price,
                _ => return Err(invalid("esa casilla no es una propiedad comprable")),
            };

            let mut players = world.resource_mut::<PlayersResource>();
            let money = *players.money.get(&cmd.player).unwrap_or(&0);
            if money < price as i64 {
                return Err(invalid(
                    "no tenés suficiente dinero para comprar esa propiedad",
                ));
            }
            players.money.insert(cmd.player, money - price as i64);
            players.properties.insert(space, cmd.player);
            let _ = players;

            events.push(Box::new(PropertyPurchasedEvent {
                player: cmd.player,
                space,
                price,
            }));

            world
                .resource_mut::<PendingPurchaseResource>()
                .pending
                .remove(&cmd.player);

            if !is_doubles {
                advance_turn_skip_bankrupt(world);
            }
        } else {
            world
                .resource_mut::<PendingPurchaseResource>()
                .pending
                .remove(&cmd.player);

            world.resource_mut::<AuctionResource>().state = Some(AuctionState {
                space,
                current_bid: 0,
                highest_bidder: None,
                passed: HashSet::new(),
            });

            events.push(Box::new(AuctionStartedEvent { space }));
        }

        Ok(events)
    });

    rules
}
