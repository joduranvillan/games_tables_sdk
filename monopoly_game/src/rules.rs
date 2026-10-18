use std::collections::HashSet;

use open_table_engine::prelude::*;

use crate::board::{
    ChanceCard, CommunityChestCard, SpaceKind, BOARD_SIZE, GO_BONUS, GO_TO_JAIL_SPACE, JAIL_SPACE,
};
use crate::commands::{
    AcceptTradeCommand, AuctionBidCommand, BuildHouseCommand, BuyPropertyCommand,
    MortgagePropertyCommand, PayJailFeeCommand, ProposeTradeCommand, RejectTradeCommand,
    RollAndMoveCommand, SellHouseCommand, UnmortgagePropertyCommand, UseJailCardCommand,
};
use crate::events::{
    AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent, ChanceCardDrawnEvent,
    CommunityChestCardDrawnEvent, GameOverEvent, HouseBuiltEvent, HouseSoldEvent,
    JailCardUsedEvent, JailedEvent, PlayerMovedEvent, PropertyMortgagedEvent,
    PropertyPurchasedEvent, PropertyUnmortgagedEvent, RailroadRentPaidEvent, RentPaidEvent,
    TaxPaidEvent, TradeAcceptedEvent, TradeProposedEvent, TradeRejectedEvent, UtilityRentPaidEvent,
};
use crate::resources::{
    AuctionResource, AuctionState, BoardResource, BuildingsResource, JailResource, PendingDecision,
    PendingPurchaseResource, PlayersResource, TradeOffer, TradeOfferResource,
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

pub fn house_cost_for_space(space: usize) -> u32 {
    if space < 10 {
        50
    } else if space < 20 {
        100
    } else if space < 30 {
        150
    } else {
        200
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
                    if world
                        .resource::<PlayersResource>()
                        .mortgaged
                        .contains(&space_idx)
                    {
                        return false;
                    }

                    let is_full_group = world.resource::<PlayersResource>().owns_full_group(
                        &board_spaces,
                        owner,
                        group,
                    );

                    if !world.contains_resource::<BuildingsResource>() {
                        world.insert_resource(BuildingsResource::default());
                    }
                    let buildings_lvl = world
                        .resource::<BuildingsResource>()
                        .buildings
                        .get(&space_idx)
                        .copied()
                        .unwrap_or(0);

                    let actual_rent = match buildings_lvl {
                        0 => {
                            if is_full_group {
                                rent * 2
                            } else {
                                *rent
                            }
                        }
                        1 => rent * 5,
                        2 => rent * 15,
                        3 => rent * 45,
                        4 => rent * 80,
                        _ => rent * 125,
                    };

                    let mut players = world.resource_mut::<PlayersResource>();
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
                    if world
                        .resource::<PlayersResource>()
                        .mortgaged
                        .contains(&space_idx)
                    {
                        return false;
                    }

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
                    if world
                        .resource::<PlayersResource>()
                        .mortgaged
                        .contains(&space_idx)
                    {
                        return false;
                    }

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
                ChanceCard::BankDividend50 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 50;
                    players.money.insert(player, money);
                    false
                }
                ChanceCard::GetOutOfJailFree => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 50;
                    players.money.insert(player, money);
                    *players.jail_free_cards.entry(player).or_insert(0) += 1;
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
                CommunityChestCard::FromSaleOfStock50 => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 50;
                    players.money.insert(player, money);
                    false
                }
                CommunityChestCard::GetOutOfJailFree => {
                    let mut players = world.resource_mut::<PlayersResource>();
                    let money = players.money.get(&player).copied().unwrap_or(0) + 50;
                    players.money.insert(player, money);
                    *players.jail_free_cards.entry(player).or_insert(0) += 1;
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
            world
                .resource_mut::<JailResource>()
                .consecutive_doubles
                .insert(cmd.player, 0);

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
        } else if is_doubles {
            let count = {
                let mut jail_res = world.resource_mut::<JailResource>();
                let entry = jail_res.consecutive_doubles.entry(cmd.player).or_insert(0);
                *entry += 1;
                *entry
            };
            if count >= 3 {
                world
                    .resource_mut::<JailResource>()
                    .consecutive_doubles
                    .insert(cmd.player, 0);
                world
                    .resource_mut::<PlayersResource>()
                    .position
                    .insert(cmd.player, JAIL_SPACE);
                world
                    .resource_mut::<JailResource>()
                    .jailed
                    .insert(cmd.player, 3);
                events.push(Box::new(PlayerMovedEvent {
                    player: cmd.player,
                    roll,
                    d1,
                    d2,
                    is_doubles: true,
                    new_position: JAIL_SPACE,
                    passed_go: false,
                }));
                events.push(Box::new(JailedEvent { player: cmd.player }));
                advance_turn_skip_bankrupt(world);
                return Ok(events);
            }
        } else {
            world
                .resource_mut::<JailResource>()
                .consecutive_doubles
                .insert(cmd.player, 0);
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

        if jailed {
            let mut jail = world.resource_mut::<JailResource>();
            jail.consecutive_doubles.insert(cmd.player, 0);
            jail.jailed.insert(cmd.player, 3);
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
            world
                .resource_mut::<JailResource>()
                .consecutive_doubles
                .insert(cmd.player, 0);
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

    rules.register::<BuildHouseCommand, _>(|cmd, world| {
        if !world.contains_resource::<BuildingsResource>() {
            world.insert_resource(BuildingsResource::default());
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let board = world.resource::<BoardResource>().spaces.clone();
        if cmd.space >= board.len() {
            return Err(invalid("casilla fuera de rango"));
        }

        let group = match &board[cmd.space] {
            SpaceKind::Property { group, .. } => group.clone(),
            _ => return Err(invalid("solo se puede construir en calles")),
        };

        let players = world.resource::<PlayersResource>();
        if players.properties.get(&cmd.space) != Some(&cmd.player) {
            return Err(invalid("no eres el dueño de esta propiedad"));
        }

        if !players.owns_full_group(&board, cmd.player, &group) {
            return Err(invalid("debes poseer todo el grupo de color para construir"));
        }

        for (idx, space) in board.iter().enumerate() {
            if let SpaceKind::Property { group: g, .. } = space {
                if g == &group && players.mortgaged.contains(&idx) {
                    return Err(invalid(
                        "no se puede construir si alguna propiedad del grupo está hipotecada",
                    ));
                }
            }
        }

        let buildings = world.resource::<BuildingsResource>();
        let current_level = buildings.buildings.get(&cmd.space).copied().unwrap_or(0);
        if current_level >= 5 {
            return Err(invalid("la propiedad ya tiene el nivel máximo (hotel)"));
        }

        let group_spaces: Vec<usize> = board
            .iter()
            .enumerate()
            .filter_map(|(idx, s)| match s {
                SpaceKind::Property { group: g, .. } if g == &group => Some(idx),
                _ => None,
            })
            .collect();

        let other_spaces: Vec<usize> = group_spaces
            .into_iter()
            .filter(|&idx| idx != cmd.space)
            .collect();
        if !other_spaces.is_empty() {
            let min_other = other_spaces
                .iter()
                .map(|&idx| buildings.buildings.get(&idx).copied().unwrap_or(0))
                .min()
                .unwrap_or(0);
            if current_level > min_other {
                return Err(invalid(
                    "regla de construcción uniforme: debes construir primero en las propiedades con menos edificios",
                ));
            }
        }

        let cost = house_cost_for_space(cmd.space);
        let player_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        if player_money < cost as i64 {
            return Err(invalid("no tienes suficiente dinero para construir"));
        }

        let _ = players;
        let _ = buildings;

        let mut players = world.resource_mut::<PlayersResource>();
        let current_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        players.money.insert(cmd.player, current_money - cost as i64);
        let _ = players;

        let mut buildings = world.resource_mut::<BuildingsResource>();
        let new_level = current_level + 1;
        buildings.buildings.insert(cmd.space, new_level);

        let events: Vec<Box<dyn Event>> = vec![Box::new(HouseBuiltEvent {
            player: cmd.player,
            space: cmd.space,
            level: new_level,
            cost,
        })];

        Ok(events)
    });

    rules.register::<SellHouseCommand, _>(|cmd, world| {
        if !world.contains_resource::<BuildingsResource>() {
            world.insert_resource(BuildingsResource::default());
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let board = world.resource::<BoardResource>().spaces.clone();
        if cmd.space >= board.len() {
            return Err(invalid("casilla fuera de rango"));
        }

        let group = match &board[cmd.space] {
            SpaceKind::Property { group, .. } => group.clone(),
            _ => return Err(invalid("solo se puede vender edificios en calles")),
        };

        let players = world.resource::<PlayersResource>();
        if players.properties.get(&cmd.space) != Some(&cmd.player) {
            return Err(invalid("no eres el dueño de esta propiedad"));
        }

        let buildings = world.resource::<BuildingsResource>();
        let current_level = buildings.buildings.get(&cmd.space).copied().unwrap_or(0);
        if current_level == 0 {
            return Err(invalid("no hay edificios construidos en esta propiedad"));
        }

        let group_spaces: Vec<usize> = board
            .iter()
            .enumerate()
            .filter_map(|(idx, s)| match s {
                SpaceKind::Property { group: g, .. } if g == &group => Some(idx),
                _ => None,
            })
            .collect();

        let other_spaces: Vec<usize> = group_spaces
            .into_iter()
            .filter(|&idx| idx != cmd.space)
            .collect();
        if !other_spaces.is_empty() {
            let max_other = other_spaces
                .iter()
                .map(|&idx| buildings.buildings.get(&idx).copied().unwrap_or(0))
                .max()
                .unwrap_or(0);
            if current_level < max_other {
                return Err(invalid(
                    "regla de desmonte uniforme: debes vender primero en las propiedades con más edificios",
                ));
            }
        }

        let cost = house_cost_for_space(cmd.space);
        let refund = cost / 2;

        let _ = players;
        let _ = buildings;

        let mut players = world.resource_mut::<PlayersResource>();
        let current_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        players.money.insert(cmd.player, current_money + refund as i64);
        let _ = players;

        let mut buildings = world.resource_mut::<BuildingsResource>();
        let new_level = current_level - 1;
        if new_level == 0 {
            buildings.buildings.remove(&cmd.space);
        } else {
            buildings.buildings.insert(cmd.space, new_level);
        }

        let events: Vec<Box<dyn Event>> = vec![Box::new(HouseSoldEvent {
            player: cmd.player,
            space: cmd.space,
            level: new_level,
            refund,
        })];

        Ok(events)
    });

    rules.register::<UseJailCardCommand, _>(|cmd, world| {
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
        let cards = players
            .jail_free_cards
            .get(&cmd.player)
            .copied()
            .unwrap_or(0);
        if cards == 0 {
            return Err(invalid("no tienes ninguna tarjeta para salir de la cárcel"));
        }
        players.jail_free_cards.insert(cmd.player, cards - 1);
        let _ = players;

        world
            .resource_mut::<JailResource>()
            .jailed
            .remove(&cmd.player);

        let events: Vec<Box<dyn Event>> = vec![Box::new(JailCardUsedEvent { player: cmd.player })];

        Ok(events)
    });

    rules.register::<MortgagePropertyCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let board = world.resource::<BoardResource>().spaces.clone();
        if cmd.space >= board.len() {
            return Err(invalid("casilla fuera de rango"));
        }

        let players = world.resource::<PlayersResource>();
        if players.properties.get(&cmd.space) != Some(&cmd.player) {
            return Err(invalid("no eres el dueño de esta propiedad"));
        }

        if players.mortgaged.contains(&cmd.space) {
            return Err(invalid("la propiedad ya está hipotecada"));
        }

        let (price, group_opt) = match &board[cmd.space] {
            SpaceKind::Property { price, group, .. } => (*price, Some(group.clone())),
            SpaceKind::Railroad { price, .. } => (*price, None),
            SpaceKind::Utility { price, .. } => (*price, None),
            _ => return Err(invalid("esta casilla no se puede hipotecar")),
        };

        if let Some(ref group) = group_opt {
            if world.contains_resource::<BuildingsResource>() {
                let buildings = world.resource::<BuildingsResource>();
                for (idx, space) in board.iter().enumerate() {
                    if let SpaceKind::Property { group: g, .. } = space {
                        if g == group && buildings.buildings.get(&idx).copied().unwrap_or(0) > 0 {
                            return Err(invalid(
                                "no se puede hipotecar una propiedad de un grupo con edificios",
                            ));
                        }
                    }
                }
            }
        }

        let _ = players;

        let mortgage_value = price / 2;
        let mut players = world.resource_mut::<PlayersResource>();
        let current_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        players
            .money
            .insert(cmd.player, current_money + mortgage_value as i64);
        players.mortgaged.insert(cmd.space);
        let _ = players;

        let events: Vec<Box<dyn Event>> = vec![Box::new(PropertyMortgagedEvent {
            player: cmd.player,
            space: cmd.space,
            amount: mortgage_value,
        })];

        Ok(events)
    });

    rules.register::<UnmortgagePropertyCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let board = world.resource::<BoardResource>().spaces.clone();
        if cmd.space >= board.len() {
            return Err(invalid("casilla fuera de rango"));
        }

        let players = world.resource::<PlayersResource>();
        if players.properties.get(&cmd.space) != Some(&cmd.player) {
            return Err(invalid("no eres el dueño de esta propiedad"));
        }

        if !players.mortgaged.contains(&cmd.space) {
            return Err(invalid("la propiedad no está hipotecada"));
        }

        let price = match &board[cmd.space] {
            SpaceKind::Property { price, .. } => *price,
            SpaceKind::Railroad { price, .. } => *price,
            SpaceKind::Utility { price, .. } => *price,
            _ => return Err(invalid("esta casilla no es una propiedad")),
        };

        let cost = (price / 2) * 110 / 100;
        let current_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        if current_money < cost as i64 {
            return Err(invalid(
                "no tienes suficiente dinero para deshipotecar la propiedad",
            ));
        }

        let _ = players;

        let mut players = world.resource_mut::<PlayersResource>();
        let current_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        players
            .money
            .insert(cmd.player, current_money - cost as i64);
        players.mortgaged.remove(&cmd.space);
        let _ = players;

        let events: Vec<Box<dyn Event>> = vec![Box::new(PropertyUnmortgagedEvent {
            player: cmd.player,
            space: cmd.space,
            cost,
        })];

        Ok(events)
    });

    rules.register::<ProposeTradeCommand, _>(|cmd, world| {
        if cmd.player == cmd.target {
            return Err(invalid("no puedes comerciar contigo mismo"));
        }

        let board = world.resource::<BoardResource>().spaces.clone();
        let players = world.resource::<PlayersResource>();

        if players.bankrupt.contains(&cmd.player) || players.bankrupt.contains(&cmd.target) {
            return Err(invalid("un jugador en bancarrota no puede comerciar"));
        }

        let player_money = players.money.get(&cmd.player).copied().unwrap_or(0);
        if player_money < cmd.offered_cash as i64 {
            return Err(invalid("no tienes suficiente efectivo para ofrecer"));
        }

        let target_money = players.money.get(&cmd.target).copied().unwrap_or(0);
        if target_money < cmd.requested_cash as i64 {
            return Err(invalid("el jugador objetivo no tiene suficiente efectivo"));
        }

        // Validar propiedades ofrecidas
        for &space_idx in &cmd.offered_spaces {
            if space_idx >= board.len() {
                return Err(invalid("casilla fuera de rango"));
            }
            if players.properties.get(&space_idx) != Some(&cmd.player) {
                return Err(invalid("no eres el dueño de una de las propiedades ofrecidas"));
            }
            if world.contains_resource::<BuildingsResource>() {
                let buildings = world.resource::<BuildingsResource>();
                if buildings.buildings.get(&space_idx).copied().unwrap_or(0) > 0 {
                    return Err(invalid("no se puede comerciar una propiedad con edificios"));
                }
                if let SpaceKind::Property { group, .. } = &board[space_idx] {
                    for (idx, space) in board.iter().enumerate() {
                        if let SpaceKind::Property { group: g, .. } = space {
                            if g == group && buildings.buildings.get(&idx).copied().unwrap_or(0) > 0 {
                                return Err(invalid(
                                    "no se puede comerciar una propiedad de un grupo con edificios",
                                ));
                            }
                        }
                    }
                }
            }
        }

        // Validar propiedades solicitadas
        for &space_idx in &cmd.requested_spaces {
            if space_idx >= board.len() {
                return Err(invalid("casilla fuera de rango"));
            }
            if players.properties.get(&space_idx) != Some(&cmd.target) {
                return Err(invalid(
                    "el objetivo no es el dueño de una de las propiedades solicitadas",
                ));
            }
            if world.contains_resource::<BuildingsResource>() {
                let buildings = world.resource::<BuildingsResource>();
                if buildings.buildings.get(&space_idx).copied().unwrap_or(0) > 0 {
                    return Err(invalid("no se puede comerciar una propiedad con edificios"));
                }
                if let SpaceKind::Property { group, .. } = &board[space_idx] {
                    for (idx, space) in board.iter().enumerate() {
                        if let SpaceKind::Property { group: g, .. } = space {
                            if g == group && buildings.buildings.get(&idx).copied().unwrap_or(0) > 0 {
                                return Err(invalid(
                                    "no se puede comerciar una propiedad de un grupo con edificios",
                                ));
                            }
                        }
                    }
                }
            }
        }

        let offer = TradeOffer {
            from: cmd.player,
            to: cmd.target,
            offered_spaces: cmd.offered_spaces.clone(),
            requested_spaces: cmd.requested_spaces.clone(),
            offered_cash: cmd.offered_cash,
            requested_cash: cmd.requested_cash,
        };

        if !world.contains_resource::<TradeOfferResource>() {
            world.insert_resource(TradeOfferResource::default());
        }
        let mut trade_res = world.resource_mut::<TradeOfferResource>();
        trade_res.set_offer(offer);

        let events: Vec<Box<dyn Event>> = vec![Box::new(TradeProposedEvent {
            player: cmd.player,
            target: cmd.target,
            offered_spaces: cmd.offered_spaces.clone(),
            requested_spaces: cmd.requested_spaces.clone(),
            offered_cash: cmd.offered_cash,
            requested_cash: cmd.requested_cash,
        })];

        Ok(events)
    });

    rules.register::<AcceptTradeCommand, _>(|cmd, world| {
        if !world.contains_resource::<TradeOfferResource>() {
            return Err(invalid("no hay ninguna oferta de intercambio activa"));
        }

        let offer = {
            let trade_res = world.resource::<TradeOfferResource>();
            trade_res
                .offer
                .as_ref()
                .ok_or_else(|| invalid("no hay ninguna oferta de intercambio activa"))?
                .clone()
        };

        if cmd.player != offer.to {
            return Err(invalid("solo el destinatario puede aceptar la oferta"));
        }

        let board = world.resource::<BoardResource>().spaces.clone();
        let players = world.resource::<PlayersResource>();

        let from_money = players.money.get(&offer.from).copied().unwrap_or(0);
        if from_money < offer.offered_cash as i64 {
            return Err(invalid("el proponente ya no tiene suficiente efectivo"));
        }
        let to_money = players.money.get(&offer.to).copied().unwrap_or(0);
        if to_money < offer.requested_cash as i64 {
            return Err(invalid(
                "no tienes suficiente efectivo para aceptar el intercambio",
            ));
        }

        for &space_idx in &offer.offered_spaces {
            if players.properties.get(&space_idx) != Some(&offer.from) {
                return Err(invalid(
                    "el proponente ya no posee una de las propiedades ofrecidas",
                ));
            }
        }
        for &space_idx in &offer.requested_spaces {
            if players.properties.get(&space_idx) != Some(&offer.to) {
                return Err(invalid("ya no posees una de las propiedades solicitadas"));
            }
        }

        if world.contains_resource::<BuildingsResource>() {
            let buildings = world.resource::<BuildingsResource>();
            for &space_idx in offer
                .offered_spaces
                .iter()
                .chain(offer.requested_spaces.iter())
            {
                if buildings.buildings.get(&space_idx).copied().unwrap_or(0) > 0 {
                    return Err(invalid("no se puede transferir una propiedad con edificios"));
                }
                if let SpaceKind::Property { group, .. } = &board[space_idx] {
                    for (idx, space) in board.iter().enumerate() {
                        if let SpaceKind::Property { group: g, .. } = space {
                            if g == group
                                && buildings.buildings.get(&idx).copied().unwrap_or(0) > 0
                            {
                                return Err(invalid(
                                    "no se puede transferir una propiedad de un grupo con edificios",
                                ));
                            }
                        }
                    }
                }
            }
        }

        let mut players = world.resource_mut::<PlayersResource>();

        for &space_idx in &offer.offered_spaces {
            players.properties.insert(space_idx, offer.to);
        }
        for &space_idx in &offer.requested_spaces {
            players.properties.insert(space_idx, offer.from);
        }

        if offer.offered_cash > 0 {
            let current_from = players.money.get(&offer.from).copied().unwrap_or(0);
            players
                .money
                .insert(offer.from, current_from - offer.offered_cash as i64);

            let current_to = players.money.get(&offer.to).copied().unwrap_or(0);
            players
                .money
                .insert(offer.to, current_to + offer.offered_cash as i64);
        }
        if offer.requested_cash > 0 {
            let current_to = players.money.get(&offer.to).copied().unwrap_or(0);
            players
                .money
                .insert(offer.to, current_to - offer.requested_cash as i64);

            let current_from = players.money.get(&offer.from).copied().unwrap_or(0);
            players
                .money
                .insert(offer.from, current_from + offer.requested_cash as i64);
        }

        let mut trade_res = world.resource_mut::<TradeOfferResource>();
        trade_res.clear();

        let events: Vec<Box<dyn Event>> = vec![Box::new(TradeAcceptedEvent {
            player: cmd.player,
            target: offer.from,
            offered_spaces: offer.offered_spaces,
            requested_spaces: offer.requested_spaces,
            offered_cash: offer.offered_cash,
            requested_cash: offer.requested_cash,
        })];

        Ok(events)
    });

    rules.register::<RejectTradeCommand, _>(|cmd, world| {
        if !world.contains_resource::<TradeOfferResource>() {
            return Err(invalid("no hay ninguna oferta de intercambio activa"));
        }

        let offer = {
            let trade_res = world.resource::<TradeOfferResource>();
            trade_res
                .offer
                .as_ref()
                .ok_or_else(|| invalid("no hay ninguna oferta de intercambio activa"))?
                .clone()
        };

        if cmd.player != offer.to && cmd.player != offer.from {
            return Err(invalid("no tienes permiso para rechazar esta oferta"));
        }

        let mut trade_res = world.resource_mut::<TradeOfferResource>();
        trade_res.clear();

        let events: Vec<Box<dyn Event>> = vec![Box::new(TradeRejectedEvent {
            player: cmd.player,
        })];

        Ok(events)
    });

    rules
}
