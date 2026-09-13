#![deny(unused_imports)]

pub mod board;
pub mod commands;
pub mod events;
pub mod i18n;
pub mod resources;
pub mod rules;

pub use i18n::territory_name;

pub use board::{
    are_adjacent, check_continent_bonus, check_objective, Continent, ContinentId, ObjectiveCard,
    Territory, TerritoryId, ADJACENCIES, CONTINENTS, CONTINENT_AFRICA, CONTINENT_ASIA,
    CONTINENT_EUROPE, CONTINENT_NORTH_AMERICA, CONTINENT_OCEANIA, CONTINENT_SOUTH_AMERICA,
    TERRITORIES, TERRITORY_CENTERS,
};
pub use commands::{
    DeclareAttackCommand, EndPhaseCommand, ExchangeCardsCommand, FortifyCommand,
    PlaceArmiesCommand, RollAttackCommand,
};
pub use events::{
    ArmiesPlacedEvent, AttackDeclaredEvent, AttackResolvedEvent, CardSymbol, CardType,
    CardsExchangedEvent, FortifiedEvent, PhaseChangedEvent, PlayerEliminatedEvent,
    TegGameOverEvent, TerritoryCard, TerritoryClaimedEvent, TerritoryConqueredEvent,
};
pub use resources::{
    BoardResource, EliminatedPlayersResource, ExchangeCountResource, PendingAttack,
    PendingAttackResource, PlayerCardsResource, PlayerHandResource, PlayerObjectivesResource,
    PlayersResource, TerritoryMapResource, TerritoryStateResource, TurnPhase, TurnPhaseResource,
    TurnStateResource,
};
use open_table_engine::turn::TurnResource;
pub use rules::{build_crisis_rules, is_valid_card_set};

use open_table_engine::prelude::*;

pub fn new_crisis_session(
    session_id: SessionId,
    seed: u64,
    players: &[PlayerId],
) -> Result<Session, EngineError> {
    if !(2..=6).contains(&players.len()) {
        return Err(EngineError::InvalidCommand {
            reason: "TEG requiere entre 2 y 6 jugadores".to_string(),
        });
    }

    let mut session = Session::new_with_metadata(
        session_id,
        "Crisis",
        seed,
        players.to_vec(),
        build_crisis_rules(),
    );

    let mut territories: Vec<TerritoryId> = (0..30u8).map(TerritoryId).collect();
    {
        let mut random_res = session.world_mut().resource_mut::<RandomResource>();
        random_res.0.shuffle(&mut territories);
    }

    let mut territory_state = TerritoryStateResource::new();
    for (i, &t_id) in territories.iter().enumerate() {
        let owner = players[i % players.len()];
        territory_state.set_owner_and_armies(t_id, owner, 1);
    }

    let extra_armies = match players.len() {
        2 => 40,
        3 => 35,
        4 => 30,
        5 => 25,
        6 => 20,
        _ => unreachable!(),
    };

    session.world_mut().insert_resource(BoardResource::new());
    session
        .world_mut()
        .insert_resource(PlayersResource::new(players));
    // Insertar explícitamente como el tipo que el test espera.
    session.world_mut().insert_resource(territory_state.clone());
    // Probamos a registrarlo específicamente bajo el alias, esperando que Bevy lo gestione correctamente.
    session.world_mut().insert_resource::<TerritoryMapResource>(territory_state);
    
    session.world_mut().insert_resource(TurnStateResource {
        phase: TurnPhase::PlaceArmies {
            armies_remaining: extra_armies,
        },
        fortified: false,
    });
    session
        .world_mut()
        .insert_resource(PendingAttackResource::default());
    session
        .world_mut()
        .insert_resource(EliminatedPlayersResource::default());
    session
        .world_mut()
        .insert_resource(ExchangeCountResource::default());
    session
        .world_mut()
        .insert_resource(PlayerCardsResource::default());
    session
        .world_mut()
        .insert_resource(TurnResource(TurnOrder::new(players.to_vec())));
    session
        .world_mut()
        .insert_resource(PlayerObjectivesResource::default());
    session
        .world_mut()
        .insert_resource(GameOverResource(false));
    session
        .world_mut()
        .insert_resource(WinnerResource(None));

    Ok(session)
}

pub fn new_crisis_session_with_players(
    session_id: SessionId,
    seed: u64,
    players: &[PlayerId],
) -> Result<Session, EngineError> {
    new_crisis_session(session_id, seed, players)
}
