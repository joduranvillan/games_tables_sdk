use serde::de::DeserializeOwned;
use serde::Serialize;
use std::fmt::Debug;

use open_table_core::ids::PlayerId;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn assert_roundtrip<T: Serialize + DeserializeOwned + Debug>(value: T) {
    let json = serde_json::to_string(&value).expect("Error al serializar a JSON");
    let deserialized: T = serde_json::from_str(&json).expect("Error al deserializar de JSON");
    let json2 = serde_json::to_string(&deserialized).expect("Error al re-serializar a JSON");
    assert_eq!(
        json, json2,
        "El JSON deserializado y re-serializado debe ser idéntico al original"
    );
}

#[test]
fn test_serialization_contract_checkers() {
    use checkers_game::{GameOverEvent, MovePieceCommand, PieceMovedEvent, Position};

    assert_roundtrip(MovePieceCommand {
        player: P1,
        from: Position::new(2, 1),
        to: Position::new(3, 2),
    });

    assert_roundtrip(PieceMovedEvent {
        player: P1,
        from: Position::new(2, 1),
        to: Position::new(3, 2),
        captured: None,
        promoted: false,
    });

    assert_roundtrip(GameOverEvent { winner: P1 });
}

#[test]
fn test_serialization_contract_chess() {
    use chess_game::{
        AcceptDrawCommand, GameOverEvent, MovePieceCommand, OfferDrawCommand, PieceMovedEvent,
        Position, ResignCommand,
    };

    assert_roundtrip(MovePieceCommand {
        player: P1,
        from: Position::new(1, 4),
        to: Position::new(3, 4),
        promote_to: None,
    });

    assert_roundtrip(OfferDrawCommand { player: P1 });
    assert_roundtrip(AcceptDrawCommand { player: P2 });
    assert_roundtrip(ResignCommand { player: P1 });

    assert_roundtrip(PieceMovedEvent {
        player: P1,
        from: Position::new(1, 4),
        to: Position::new(3, 4),
        captured: None,
        promoted_to: None,
        promoted: false,
        opponent_in_check: false,
        castled: false,
    });

    assert_roundtrip(GameOverEvent { winner: Some(P1) });
}

#[test]
fn test_serialization_contract_chinese_checkers() {
    use chinese_checkers_game::{GameOverEvent, MovePegCommand, PegMovedEvent, Position};

    assert_roundtrip(MovePegCommand {
        player: P1,
        from: Position::new(0, 0),
        to: Position::new(1, 1),
        path: vec![Position::new(0, 0), Position::new(1, 1)],
    });

    assert_roundtrip(PegMovedEvent {
        player: P1,
        from: Position::new(0, 0),
        to: Position::new(1, 1),
        was_jump: false,
    });

    assert_roundtrip(GameOverEvent { winner: Some(P1) });
}

#[test]
fn test_serialization_contract_backgammon() {
    use backgammon_game::{
        AcceptDoubleCommand, CheckerMovedEvent, DiceRolledEvent, DoubleAcceptedEvent,
        DoubleOfferedEvent, DoubleRejectedEvent, GameOverEvent, MoveCheckerCommand,
        NoValidMovesEvent, OfferDoubleCommand, RejectDoubleCommand, ResignCommand, RollDiceCommand,
    };

    assert_roundtrip(RollDiceCommand { player: P1 });
    assert_roundtrip(MoveCheckerCommand {
        player: P1,
        from: Some(0),
        die: 3,
    });
    assert_roundtrip(OfferDoubleCommand { player: P1 });
    assert_roundtrip(AcceptDoubleCommand { player: P2 });
    assert_roundtrip(RejectDoubleCommand { player: P2 });
    assert_roundtrip(ResignCommand { player: P1 });

    assert_roundtrip(DiceRolledEvent {
        player: P1,
        values: vec![3, 5],
    });
    assert_roundtrip(CheckerMovedEvent {
        player: P1,
        from: Some(0),
        to: Some(3),
        captured_opponent: false,
        borne_off: false,
    });
    assert_roundtrip(DoubleOfferedEvent { player: P1 });
    assert_roundtrip(DoubleAcceptedEvent {
        player: P2,
        value: 2,
    });
    assert_roundtrip(DoubleRejectedEvent {
        player: P2,
        value: 1,
    });
    assert_roundtrip(NoValidMovesEvent { player: P1 });
    assert_roundtrip(GameOverEvent {
        winner: P1,
        gammon: false,
        backgammon: false,
        score: 1,
    });
}

#[test]
fn test_serialization_contract_crisis() {
    use crisis_game::{
        ArmiesPlacedEvent, AttackDeclaredEvent, AttackResolvedEvent, CardsExchangedEvent,
        DeclareAttackCommand, EndPhaseCommand, ExchangeCardsCommand, FortifiedEvent,
        FortifyCommand, PhaseChangedEvent, PlaceArmiesCommand, PlayerEliminatedEvent,
        RollAttackCommand, TegGameOverEvent, TerritoryClaimedEvent, TerritoryConqueredEvent,
        TerritoryId,
    };

    assert_roundtrip(PlaceArmiesCommand {
        player: P1,
        territory: TerritoryId(0),
        count: 2,
    });
    assert_roundtrip(DeclareAttackCommand {
        player: P1,
        from: TerritoryId(0),
        to: TerritoryId(1),
        dice: 3,
    });
    assert_roundtrip(RollAttackCommand { player: P1 });
    assert_roundtrip(FortifyCommand {
        player: P1,
        from: TerritoryId(0),
        to: TerritoryId(1),
        armies: 2,
    });
    assert_roundtrip(EndPhaseCommand { player: P1 });
    assert_roundtrip(ExchangeCardsCommand {
        player: P1,
        card_indices: [0, 1, 2],
    });

    assert_roundtrip(TerritoryClaimedEvent {
        player: P1,
        territory: TerritoryId(0),
        armies: 1,
    });
    assert_roundtrip(ArmiesPlacedEvent {
        player: P1,
        territory: TerritoryId(0),
        count: 2,
        armies_remaining: 3,
    });
    assert_roundtrip(AttackDeclaredEvent {
        attacker: P1,
        from: TerritoryId(0),
        to: TerritoryId(1),
        dice: 3,
    });
    assert_roundtrip(AttackResolvedEvent {
        attacker: P1,
        defender: P2,
        from: TerritoryId(0),
        to: TerritoryId(1),
        attacker_rolls: vec![6, 5],
        defender_rolls: vec![4],
        attacker_losses: 0,
        defender_losses: 1,
        territory_conquered: false,
    });
    assert_roundtrip(TerritoryConqueredEvent {
        player: P1,
        territory: TerritoryId(1),
        from: TerritoryId(0),
        from_armies: 3,
        to_armies: 3,
        card_drawn: None,
    });
    assert_roundtrip(PlayerEliminatedEvent { player: P2, by: P1 });
    assert_roundtrip(FortifiedEvent {
        player: P1,
        from: TerritoryId(0),
        to: TerritoryId(1),
        armies: 2,
    });
    assert_roundtrip(CardsExchangedEvent {
        player: P1,
        armies_gained: 4,
    });
    assert_roundtrip(PhaseChangedEvent {
        player: P1,
        new_phase: "Attack".to_string(),
    });
    assert_roundtrip(TegGameOverEvent {
        winner: P1,
        objective: "Conquer South America".to_string(),
    });
}

#[test]
fn test_serialization_contract_go() {
    use go_game::{
        ConfirmDeadCommand, GameOverEvent, MarkDeadCommand, PassCommand, PassedEvent,
        PlaceHandicapCommand, PlaceStoneCommand, ResignCommand, StonePlacedEvent,
        StonesCapturedEvent,
    };

    assert_roundtrip(PlaceStoneCommand {
        player: P1,
        x: 4,
        y: 4,
    });
    assert_roundtrip(PassCommand { player: P1 });
    assert_roundtrip(PlaceHandicapCommand {
        player: P1,
        positions: vec![(2, 2)],
    });
    assert_roundtrip(MarkDeadCommand {
        player: P1,
        positions: vec![(1, 1)],
    });
    assert_roundtrip(ConfirmDeadCommand { player: P1 });
    assert_roundtrip(ResignCommand { player: P1 });

    assert_roundtrip(StonePlacedEvent {
        player: P1,
        x: 4,
        y: 4,
    });
    assert_roundtrip(StonesCapturedEvent {
        player: P1,
        count: 2,
    });
    assert_roundtrip(PassedEvent { player: P1 });
    assert_roundtrip(GameOverEvent {
        winner: Some(P1),
        reason: "Normal".to_string(),
    });
}

#[test]
fn test_serialization_contract_ludo() {
    use ludo_game::{
        DiceRolledEvent, GameOverEvent, MoveTokenCommand, NoValidMovesEvent, RollDiceCommand,
        TokenMovedEvent,
    };

    assert_roundtrip(RollDiceCommand { player: P1 });
    assert_roundtrip(MoveTokenCommand {
        player: P1,
        token_index: 0,
    });

    assert_roundtrip(DiceRolledEvent {
        player: P1,
        value: 6,
    });
    assert_roundtrip(TokenMovedEvent {
        player: P1,
        token_index: 0,
        from_steps: 0,
        to_steps: 6,
        captured: None,
        finished: false,
    });
    assert_roundtrip(NoValidMovesEvent {
        player: P1,
        value: 3,
    });
    assert_roundtrip(GameOverEvent { winner: P1 });
}

#[test]
fn test_serialization_contract_mille_bornes() {
    use mille_bornes_game::{
        Card, CardDiscardedEvent, CardDrawnEvent, CoupFourreCommand, DiscardCardCommand,
        DistancePlayedEvent, DrawCardCommand, GameOverEvent, Hazard, HazardPlayedEvent,
        PlayCardCommand, PlayDistanceCommand, PlayHazardCommand, PlaySafetyCommand,
        RemedyPlayedEvent, Safety, SafetyPlayedEvent, TripExtendedEvent,
    };

    assert_roundtrip(PlayCardCommand {
        player: P1,
        card_index: 0,
    });
    assert_roundtrip(DiscardCardCommand {
        player: P1,
        card_index: 0,
    });
    assert_roundtrip(DrawCardCommand { player: P1 });
    assert_roundtrip(PlayDistanceCommand {
        player: P1,
        distance: 25,
    });
    assert_roundtrip(PlayHazardCommand {
        player: P1,
        target: P2,
        hazard: Hazard::OutOfGas,
    });
    assert_roundtrip(PlaySafetyCommand {
        player: P1,
        safety: Safety::RightOfWay,
    });
    assert_roundtrip(CoupFourreCommand { player: P1 });

    assert_roundtrip(CardDiscardedEvent {
        player: P1,
        card: Card::Distance(25),
    });
    assert_roundtrip(CardDrawnEvent {
        player: P1,
        card: Card::Distance(25),
    });
    assert_roundtrip(DistancePlayedEvent {
        player: P1,
        value: 25,
        new_distance: 25,
    });
    assert_roundtrip(HazardPlayedEvent {
        player: P1,
        target: P2,
        hazard: Hazard::OutOfGas,
    });
    assert_roundtrip(RemedyPlayedEvent {
        player: P1,
        hazard: Hazard::OutOfGas,
    });
    assert_roundtrip(SafetyPlayedEvent {
        player: P1,
        safety: Safety::RightOfWay,
    });
    assert_roundtrip(TripExtendedEvent { new_target: 1000 });
    assert_roundtrip(GameOverEvent { winner: P1 });
}

#[test]
fn test_serialization_contract_monopoly() {
    use monopoly_game::{
        AuctionBidCommand, AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent,
        BuyPropertyCommand, GameOverEvent, JailedEvent, PayJailFeeCommand, PlayerMovedEvent,
        PropertyPurchasedEvent, RailroadRentPaidEvent, RentPaidEvent, RollAndMoveCommand,
        UtilityRentPaidEvent,
    };

    assert_roundtrip(RollAndMoveCommand { player: P1 });
    assert_roundtrip(BuyPropertyCommand {
        player: P1,
        buy: true,
    });
    assert_roundtrip(PayJailFeeCommand { player: P1 });
    assert_roundtrip(AuctionBidCommand {
        player: P1,
        amount: 100,
    });

    assert_roundtrip(PlayerMovedEvent {
        player: P1,
        roll: 3,
        d1: 1,
        d2: 2,
        is_doubles: false,
        new_position: 3,
        passed_go: false,
    });
    assert_roundtrip(PropertyPurchasedEvent {
        player: P1,
        space: 1,
        price: 60,
    });
    assert_roundtrip(RentPaidEvent {
        payer: P1,
        owner: P2,
        space: 1,
        amount: 10,
    });
    assert_roundtrip(RailroadRentPaidEvent {
        player: P1,
        owner: P2,
        railroads_owned: 1,
        amount: 25,
    });
    assert_roundtrip(UtilityRentPaidEvent {
        player: P1,
        owner: P2,
        multiplier: 4,
        dice_total: 5,
        amount: 20,
    });
    assert_roundtrip(JailedEvent { player: P1 });
    assert_roundtrip(AuctionStartedEvent { space: 1 });
    assert_roundtrip(AuctionWonEvent {
        player: P1,
        space: 1,
        price: 100,
    });
    assert_roundtrip(BankruptcyEvent { player: P1 });
    assert_roundtrip(GameOverEvent { winner: P1 });
}

#[test]
fn test_serialization_contract_shogi() {
    use shogi_game::{
        DropPieceCommand, GameOverEvent, MovePieceCommand, PieceDroppedEvent, PieceKind,
        PieceMovedEvent, ResignCommand,
    };

    assert_roundtrip(MovePieceCommand {
        player: P1,
        from: (6, 6),
        to: (5, 6),
        promote: false,
    });
    assert_roundtrip(DropPieceCommand {
        player: P1,
        piece: PieceKind::Pawn,
        to: (4, 4),
    });
    assert_roundtrip(ResignCommand { player: P1 });

    assert_roundtrip(PieceMovedEvent {
        player: P1,
        from: (6, 6),
        to: (5, 6),
        captured: None,
        promoted: false,
    });
    assert_roundtrip(PieceDroppedEvent {
        player: P1,
        piece: PieceKind::Pawn,
        to: (4, 4),
    });
    assert_roundtrip(GameOverEvent { winner: Some(P1) });
}

#[test]
fn test_serialization_contract_uno() {
    use uno_game::{
        Card, CardColor, CardPlayedEvent, CardValue, CardsDrawnEvent, DrawCardCommand,
        DrewAndPlayedEvent, GameOverEvent, PlayCardCommand, PlayerSkippedEvent, TurnReversedEvent,
    };

    assert_roundtrip(PlayCardCommand {
        player: P1,
        card_index: 0,
        chosen_color: None,
    });
    assert_roundtrip(DrawCardCommand { player: P1 });

    assert_roundtrip(CardPlayedEvent {
        player: P1,
        card: Card::new(CardColor::Red, CardValue::Number(5)),
        new_color: CardColor::Red,
    });
    assert_roundtrip(CardsDrawnEvent {
        player: P1,
        count: 1,
    });
    assert_roundtrip(TurnReversedEvent {});
    assert_roundtrip(PlayerSkippedEvent { skipped_player: P1 });
    assert_roundtrip(DrewAndPlayedEvent {
        player: P1,
        card: Card::new(CardColor::Red, CardValue::Number(5)),
        new_color: CardColor::Red,
    });
    assert_roundtrip(GameOverEvent { winner: P1 });
}

#[test]
fn test_serialization_contract_xiangqi() {
    use xiangqi_game::{GameOverEvent, MovePieceCommand, PieceMovedEvent, ResignCommand};

    assert_roundtrip(MovePieceCommand {
        player: P1,
        from: (9, 0),
        to: (8, 0),
    });
    assert_roundtrip(ResignCommand { player: P1 });

    assert_roundtrip(PieceMovedEvent {
        player: P1,
        from: (9, 0),
        to: (8, 0),
        captured: None,
    });
    assert_roundtrip(GameOverEvent { winner: Some(P1) });
}
