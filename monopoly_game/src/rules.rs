use std::collections::HashSet;

use open_table_engine::prelude::*;

use crate::board::{
    ChanceCard, CommunityChestCard, SpaceKind, BOARD_SIZE, GO_BONUS, GO_TO_JAIL_SPACE, JAIL_SPACE,
};
use crate::commands::{
    AuctionBidCommand, BuyPropertyCommand, PayJailFeeCommand, RollAndMoveCommand,
};
use crate::events::{
    AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent, ChanceCardDrawnEvent,
    CommunityChestCardDrawnEvent, GameOverEvent, JailedEvent, PlayerMovedEvent,
    PropertyPurchasedEvent, RailroadRentPaidEvent, RentPaidEvent, TaxPaidEvent,
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

/// Aplica el efecto de caer en una casilla determinada.
/// Devuelve `true` si el jugador debe tomar una decisión (e.g. comprar propiedad)
/// antes de que el turno pueda avanzar.
pub fn apply_land_effect(
    space: &SpaceKind,
    space_idx: usize,
    player: PlayerId,
    roll: u32,
    is_doubles: bool,
    world: &mut BevyWorld,
    events: &mut Vec<Box<dyn Event>>,
) -> bool {
    let board_spaces = world.resource::<BoardResource>().spaces.clone();

    match space {
        SpaceKind::Property {
            ref group, rent, ..
        } => {
            let owner = world
                .resource::<PlayersResource>()
                .properties
                .get(&space_idx)
                .copied();
            match owner {
                None => {
                    world
                        .resource_mut::<PendingPurchaseResource>()
                        .pending
                        .insert(
                            player,
                            PendingDecision {
                                space: space_idx,
                                is_doubles,
                            },
                        );
                    true
                }
                Some(owner) if owner == player => false,
                Some(owner) => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let is_full_group = players.owns_full_group(&board_spaces, owner, group);
                    let actual_rent = if is_full_group { rent * 2 } else { *rent };

                    let payer_money =
                        players.money.get(&player).copied().unwrap_or(0) - actual_rent as i64;
                    players.money.insert(player, payer_money);
                    *players.money.entry(owner).or_insert(0) += actual_rent as i64;
                    let _ = players;

                    events.push(Box::new(RentPaidEvent {
                        payer: player,
                        owner,
                        space: space_idx,
                        amount: actual_rent,
                    }));

                    if payer_money < 0 {
                        handle_bankruptcy(player, Some(owner), world, events);
                    }
                    false
                }
            }
        }
        SpaceKind::Utility { .. } => {
            let owner = world
                .resource::<PlayersResource>()
                .properties
                .get(&space_idx)
                .copied();
            match owner {
                None => {
                    world
                        .resource_mut::<PendingPurchaseResource>()
                        .pending
                        .insert(
                            player,
                            PendingDecision {
                                space: space_idx,
                                is_doubles,
                            },
                        );
                    true
                }
                Some(owner) if owner == player => false,
                Some(owner) => {
                    let count = world
                        .resource::<PlayersResource>()
                        .count_utilities(&board_spaces, owner);
                    let multiplier = if count >= 2 { 10 } else { 4 };
                    let actual_rent = multiplier * roll;

                    let mut players = world.resource_mut::<PlayersResource>();
                    let payer_money =
                        players.money.get(&player).copied().unwrap_or(0) - actual_rent as i64;
                    players.money.insert(player, payer_money);
                    *players.money.entry(owner).or_insert(0) += actual_rent as i64;
                    let _ = players;

                    events.push(Box::new(UtilityRentPaidEvent {
                        player,
                        owner,
                        multiplier,
                        dice_total: roll,
                        amount: actual_rent,
                    }));

                    if payer_money < 0 {
                        handle_bankruptcy(player, Some(owner), world, events);
                    }
                    false
                }
            }
        }
        SpaceKind::Railroad { .. } => {
            let owner = world
                .resource::<PlayersResource>()
                .properties
                .get(&space_idx)
                .copied();
            match owner {
                None => {
                    world
                        .resource_mut::<PendingPurchaseResource>()
                        .pending
                        .insert(
                            player,
                            PendingDecision {
                                space: space_idx,
                                is_doubles,
                            },
                        );
                    true
                }
                Some(owner) if owner == player => false,
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
                    let payer_money =
                        players.money.get(&player).copied().unwrap_or(0) - actual_rent as i64;
                    players.money.insert(player, payer_money);
                    *players.money.entry(owner).or_insert(0) += actual_rent as i64;
                    let _ = players;

                    events.push(Box::new(RailroadRentPaidEvent {
                        player,
                        owner,
                        railroads_owned: count,
                        amount: actual_rent,
                    }));

                    if payer_money < 0 {
                        handle_bankruptcy(player, Some(owner), world, events);
                    }
                    false
                }
            }
        }
        SpaceKind::Tax { ref name, amount } => {
            let mut players = world.resource_mut::<PlayersResource>();
            let money = players.money.get(&player).copied().unwrap_or(0) - *amount as i64;
            players.money.insert(player, money);
            let _ = players;

            events.push(Box::new(TaxPaidEvent {
                player,
                space: space_idx,
                name: name.clone(),
                amount: *amount,
            }));

            if money < 0 {
                handle_bankruptcy(player, None, world, events);
            }
            false
        }
        SpaceKind::GoToJail => {
            let mut players = world.resource_mut::<PlayersResource>();
            players.position.insert(player, JAIL_SPACE);
            let _ = players;

            world
                .resource_mut::<JailResource>()
                .jailed
                .insert(player, 3);
            events.push(Box::new(JailedEvent { player }));
            false
        }
        SpaceKind::Chance => {
            let card_idx = {
                let mut rng = world.resource_mut::<RandomResource>();
                (rng.0.roll_die(10) - 1) as usize
            };
            let card = ChanceCard::ALL[card_idx % ChanceCard::ALL.len()];

            events.push(Box::new(ChanceCardDrawnEvent {
                player,
                card,
                description: card.description().to_string(),
            }));

            match card {
                ChanceCard::AdvanceToGo => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    players.position.insert(player, 0);
                    let money = players.money.get(&player).copied().unwrap_or(0) + GO_BONUS;
                    players.money.insert(player, money);
                    false
                }
                ChanceCard::AdvanceToIllinois => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let old_pos = players.position.get(&player).copied().unwrap_or(0);
                    let mut money = players.money.get(&player).copied().unwrap_or(0);
                    if old_pos > 24 {
                        money += GO_BONUS;
                    }
                    players.position.insert(player, 24);
                    players.money.insert(player, money);
                    let _ = players;

                    let illinois = board_spaces[24].clone();
                    apply_land_effect(&illinois, 24, player, roll, is_doubles, world, events)
                }
                ChanceCard::AdvanceToStCharles => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let old_pos = players.position.get(&player).copied().unwrap_or(0);
                    let mut money = players.money.get(&player).copied().unwrap_or(0);
                    if old_pos > 11 {
                        money += GO_BONUS;
                    }
                    players.position.insert(player, 11);
                    players.money.insert(player, money);
                    let _ = players;

                    let st_charles = board_spaces[11].clone();
                    apply_land_effect(&st_charles, 11, player, roll, is_doubles, world, events)
                }
                ChanceCard::AdvanceToUtility => {
                    let old_pos = world
                        .resource::<PlayersResource>()
                        .position
                        .get(&player)
                        .copied()
                        .unwrap_or(0);
                    let target_util = if !(12..=28).contains(&old_pos) {
                        12
                    } else {
                        28
                    };
                    let mut players = world.resource_mut::<PlayersResource>();
                    let mut money = players.money.get(&player).copied().unwrap_or(0);
                    if old_pos > 28 {
                        money += GO_BONUS;
                    }
                    players.position.insert(player, target_util);
                    players.money.insert(player, money);
                    let _ = players;

                    let util_space = board_spaces[target_util].clone();
                    apply_land_effect(
                        &util_space,
                        target_util,
                        player,
                        roll,
                        is_doubles,
                        world,
                        events,
                    )
                }
                ChanceCard::AdvanceToRailroad => {
                    let old_pos = world
                        .resource::<PlayersResource>()
                        .position
                        .get(&player)
                        .copied()
                        .unwrap_or(0);
                    let target_rr = if old_pos < 5 {
                        5
                    } else if old_pos < 15 {
                        15
                    } else if old_pos < 25 {
                        25
                    } else if old_pos < 35 {
                        35
                    } else {
                        5
                    };
                    let mut players = world.resource_mut::<PlayersResource>();
                    let mut money = players.money.get(&player).copied().unwrap_or(0);
                    if old_pos >= 35 {
                        money += GO_BONUS;
                    }
                    players.position.insert(player, target_rr);
                    players.money.insert(player, money);
                    let _ = players;

                    let rr_space = board_spaces[target_rr].clone();
                    apply_land_effect(
                        &rr_space, target_rr, player, roll, is_doubles, world, events,
                    )
                }
                ChanceCard::BankDividend50 | ChanceCard::GetOutOfJailFree => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 50;
                    players.money.insert(player, money);
                    false
                }
                ChanceCard::GoBack3Spaces => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let old_pos = players.position.get(&player).copied().unwrap_or(0);
                    let new_pos = (old_pos + BOARD_SIZE - 3) % BOARD_SIZE;
                    players.position.insert(player, new_pos);
                    let _ = players;

                    let space = board_spaces[new_pos].clone();
                    apply_land_effect(&space, new_pos, player, roll, is_doubles, world, events)
                }
                ChanceCard::GoToJail => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    players.position.insert(player, JAIL_SPACE);
                    let _ = players;

                    world
                        .resource_mut::<JailResource>()
                        .jailed
                        .insert(player, 3);
                    events.push(Box::new(JailedEvent { player }));
                    false
                }
                ChanceCard::SpeedingFine15 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) - 15;
                    players.money.insert(player, money);
                    let _ = players;

                    if money < 0 {
                        handle_bankruptcy(player, None, world, events);
                    }
                    false
                }
            }
        }
        SpaceKind::CommunityChest => {
            let card_idx = {
                let mut rng = world.resource_mut::<RandomResource>();
                (rng.0.roll_die(10) - 1) as usize
            };
            let card = CommunityChestCard::ALL[card_idx % CommunityChestCard::ALL.len()];

            events.push(Box::new(CommunityChestCardDrawnEvent {
                player,
                card,
                description: card.description().to_string(),
            }));

            match card {
                CommunityChestCard::AdvanceToGo => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    players.position.insert(player, 0);
                    let money = players.money.get(&player).copied().unwrap_or(0) + GO_BONUS;
                    players.money.insert(player, money);
                    false
                }
                CommunityChestCard::BankError200 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 200;
                    players.money.insert(player, money);
                    false
                }
                CommunityChestCard::DoctorFee50 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) - 50;
                    players.money.insert(player, money);
                    let _ = players;

                    if money < 0 {
                        handle_bankruptcy(player, None, world, events);
                    }
                    false
                }
                CommunityChestCard::FromSaleOfStock50 | CommunityChestCard::GetOutOfJailFree => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 50;
                    players.money.insert(player, money);
                    false
                }
                CommunityChestCard::GoToJail => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    players.position.insert(player, JAIL_SPACE);
                    let _ = players;

                    world
                        .resource_mut::<JailResource>()
                        .jailed
                        .insert(player, 3);
                    events.push(Box::new(JailedEvent { player }));
                    false
                }
                CommunityChestCard::HolidayFund100 | CommunityChestCard::LifeInsurance100 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 100;
                    players.money.insert(player, money);
                    false
                }
                CommunityChestCard::IncomeTaxRefund20 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 20;
                    players.money.insert(player, money);
                    false
                }
                CommunityChestCard::HospitalFee100 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) - 100;
                    players.money.insert(player, money);
                    let _ = players;

                    if money < 0 {
                        handle_bankruptcy(player, None, world, events);
                    }
                    false
                }
            }
        }
        SpaceKind::Go | SpaceKind::Jail | SpaceKind::FreeParking => false,
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
        let landed_pos = new_pos;
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
            new_position: landed_pos,
            passed_go,
        }));

        if jailed {
            events.push(Box::new(JailedEvent { player: cmd.player }));
        }

        let mut awaiting_decision = false;

        if !jailed {
            let space = board_spaces[new_pos].clone();
            awaiting_decision = apply_land_effect(
                &space,
                new_pos,
                cmd.player,
                roll,
                is_doubles,
                world,
                &mut events,
            );
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
                SpaceKind::Property { price, .. } => *price,
                SpaceKind::Utility { price, .. } => *price,
                SpaceKind::Railroad { price, .. } => *price,
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
