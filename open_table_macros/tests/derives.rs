//! Reescribe el ejemplo del juego de dados y agrega uno de cartas, ahora
//! usando los derives en vez de escribir `as_any()` / `Resource` /
//! `Component` a mano. Si esto compila y pasa, los derives realmente
//! eliminan el boilerplate que tenían los ejemplos anteriores.

use open_table_core::prelude::*;
use open_table_macros::{GameCommand, GameComponent, GameEvent, GameResource};
use serde::{Deserialize, Serialize};

// ---- Comando con #[issuer]: no escribimos as_any() a mano ----

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
struct RollDiceCommand {
    #[issuer]
    player: PlayerId,
}

// ---- Evento público: sin atributos, visibility() queda en Public ----

#[derive(Debug, Serialize, Deserialize, GameEvent)]
struct DiceRolledEvent {
    player: PlayerId,
    value: u32,
}

// ---- Evento privado con #[owner]: información oculta sin código a mano ----

#[derive(Debug, Serialize, Deserialize, GameEvent)]
struct CardDrawnEvent {
    #[owner]
    player: PlayerId,
    card_name: String,
}

// ---- Resource: bevy_ecs::system::Resource generado por el derive ----

#[derive(GameResource)]
struct TurnCounter {
    turns_played: u32,
}

// ---- Component: bevy_ecs::component::Component generado por el derive ----

#[derive(Debug, GameComponent)]
struct BoardPosition {
    tile: u32,
}

#[test]
fn comando_con_issuer_declarativo_funciona() {
    let alice = PlayerId(7);
    let cmd = RollDiceCommand { player: alice };

    // El derive generó issuer() a partir de #[issuer], no lo escribimos.
    assert_eq!(cmd.issuer(), Some(alice));
    assert_eq!(
        cmd.as_any()
            .downcast_ref::<RollDiceCommand>()
            .unwrap()
            .player,
        alice
    );
}

#[test]
fn evento_publico_por_defecto_y_evento_con_owner_declarativo() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);

    let public_event: Box<dyn Event> = Box::new(DiceRolledEvent {
        player: alice,
        value: 4,
    });
    assert!(public_event.visibility().includes(bob));

    let private_event: Box<dyn Event> = Box::new(CardDrawnEvent {
        player: alice,
        card_name: "Rey de corazones".to_string(),
    });
    assert!(private_event.visibility().includes(alice));
    assert!(!private_event.visibility().includes(bob));
}

#[test]
fn resource_generado_se_puede_insertar_en_un_world_de_bevy_ecs() {
    let mut world = bevy_ecs::world::World::new();
    world.insert_resource(TurnCounter { turns_played: 0 });

    let mut counter = world.resource_mut::<TurnCounter>();
    counter.turns_played += 1;

    assert_eq!(world.resource::<TurnCounter>().turns_played, 1);
}

#[test]
fn component_generado_se_puede_usar_en_una_entidad_de_bevy_ecs() {
    let mut world = bevy_ecs::world::World::new();
    let entity = world.spawn(BoardPosition { tile: 3 }).id();

    assert_eq!(world.get::<BoardPosition>(entity).unwrap().tile, 3);
}
