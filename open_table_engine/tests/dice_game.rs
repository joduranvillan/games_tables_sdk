// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct RollDiceCommand {
    player: PlayerId,
}

#[typetag::serde]
impl Command for RollDiceCommand {
    fn clone_box(&self) -> Box<dyn Command> {
        Box::new(self.clone())
    }

    fn issuer(&self) -> Option<PlayerId> {
        Some(self.player)
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct DiceRolledEvent {
    player: PlayerId,
    value: u32,
}

#[typetag::serde]
impl Event for DiceRolledEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Evento privado, para probar el resync filtrado por Visibility.
#[derive(Debug, Serialize, Deserialize)]
struct SecretNoteEvent {
    owner: PlayerId,
    text: String,
}

#[typetag::serde]
impl Event for SecretNoteEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    fn visibility(&self) -> Visibility {
        Visibility::Owner(self.owner)
    }
}

fn build_dice_game_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<RollDiceCommand, _>(|cmd, world| {
        let mut rng = world.resource_mut::<RandomResource>();
        let value = rng.0.roll_die(6);

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            value,
        })];

        // Un "6" da una nota secreta que solo el jugador ve, para poder
        // probar el filtrado de visibilidad en el resync.
        if value == 6 {
            events.push(Box::new(SecretNoteEvent {
                owner: cmd.player,
                text: "sacaste un 6, jugada de nuevo".to_string(),
            }));
        }

        // Pasa el turno al siguiente jugador.
        world.resource_mut::<TurnResource>().0.advance();

        Ok(events)
    });

    rules
}

#[test]
fn pipeline_completo_comando_a_evento_con_seed_determinista() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let players = vec![alice, bob];

    let mut session_a = Session::new(SessionId(1), 42, players.clone(), build_dice_game_rules());
    let mut session_b = Session::new(SessionId(2), 42, players, build_dice_game_rules());

    let events_a = session_a
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .expect("procesa");
    let events_b = session_b
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .expect("procesa");

    assert_eq!(
        format!("{events_a:?}"),
        format!("{events_b:?}"),
        "misma seed debe dar el mismo resultado"
    );
    assert_eq!(session_a.current_tick(), Tick(1));
}

#[test]
fn test_force_turn_helper() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let mut session = Session::new(SessionId(20), 1, vec![alice, bob], build_dice_game_rules());

    assert_eq!(session.current_player(), alice);
    force_turn!(session, bob);
    assert_eq!(session.current_player(), bob);
    force_turn!(session, alice);
    assert_eq!(session.current_player(), alice);
}

#[test]
fn el_turno_pasa_al_siguiente_jugador_tras_cada_comando() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let mut session = Session::new(SessionId(1), 7, vec![alice, bob], build_dice_game_rules());

    assert_eq!(session.current_player(), alice);
    session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .expect("procesa");
    assert_eq!(session.current_player(), bob);
}

#[test]
fn comando_sin_regla_registrada_es_rechazado() {
    #[derive(Debug, Clone, Serialize, Deserialize)]
    struct ComandoFantasma;

    #[typetag::serde]
    impl Command for ComandoFantasma {
        fn clone_box(&self) -> Box<dyn Command> {
            Box::new(self.clone())
        }

        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    }

    let mut session = Session::new(SessionId(3), 1, vec![PlayerId(1)], build_dice_game_rules());
    let result = session.process_command(PlayerId(1), Box::new(ComandoFantasma));

    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn comando_con_issuer_distinto_del_sender_real_es_rechazado() {
    let alice = PlayerId(1);
    let mallory = PlayerId(99); // conexión de red real de quien manda los bytes

    let mut session = Session::new(SessionId(4), 1, vec![alice], build_dice_game_rules());

    // El payload dice "soy Alice", pero la conexión que trajo estos bytes
    // es Mallory. Esto simula un cliente falsificando el campo issuer.
    let forged = RollDiceCommand { player: alice };
    let result = session.process_command(mallory, Box::new(forged));

    assert!(matches!(result, Err(EngineError::Unauthorized(id)) if id == mallory));
}

#[test]
fn replay_reproduce_exactamente_los_mismos_eventos() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let players = vec![alice, bob];

    let mut original = Session::new(SessionId(5), 123, players.clone(), build_dice_game_rules());
    original
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .unwrap();
    original
        .process_command(bob, Box::new(RollDiceCommand { player: bob }))
        .unwrap();

    let log_bytes = original.export_log().expect("exporta el log");

    let replayed = Session::replay(
        SessionId(5),
        123,
        players,
        build_dice_game_rules(),
        &log_bytes,
    )
    .expect("reproduce la partida");

    assert_eq!(replayed.current_tick(), original.current_tick());
    assert_eq!(replayed.current_player(), original.current_player());
}

#[test]
fn resync_solo_manda_al_jugador_los_eventos_que_puede_ver() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let players = vec![alice, bob];

    let mut original = Session::new(SessionId(6), 555, players.clone(), build_dice_game_rules());
    // Corremos varios turnos para tener buenas chances de generar algún
    // SecretNoteEvent (seed fija, así que el resultado es reproducible).
    for _ in 0..8 {
        let current = original.current_player();
        original
            .process_command(current, Box::new(RollDiceCommand { player: current }))
            .unwrap();
    }

    let log_bytes = original.export_log().unwrap();

    let (_replayed, all_events) = Session::replay_collecting_events(
        SessionId(6),
        555,
        players,
        build_dice_game_rules(),
        &log_bytes,
    )
    .expect("reproduce y junta eventos");

    // Alice reconectándose: nunca debe recibir la nota secreta de Bob.
    let alice_view = filter_events_for_player(&all_events, alice);
    for event in &alice_view {
        if let Some(note) = event.as_any().downcast_ref::<SecretNoteEvent>() {
            assert_eq!(
                note.owner, alice,
                "Alice no puede ver una nota secreta de otro jugador"
            );
        }
    }
}

#[test]
fn spectator_recibe_eventos_publicos() {
    let alice = PlayerId(1);
    let spectator = SpectatorId(100);

    let mut session = Session::new(SessionId(10), 42, vec![alice], build_dice_game_rules());
    let events = session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .expect("procesa comando");

    let spectator_events = filter_events_for_spectator(&events, spectator);

    assert!(
        !spectator_events.is_empty(),
        "los eventos públicos deben llegar al espectador"
    );
    let has_dice_rolled = spectator_events
        .iter()
        .any(|e| e.as_any().downcast_ref::<DiceRolledEvent>().is_some());
    assert!(
        has_dice_rolled,
        "DiceRolledEvent público debe llegar al espectador"
    );
}

#[test]
fn spectator_no_recibe_eventos_privados() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let spectator = SpectatorId(100);
    let players = vec![alice, bob];

    let mut original = Session::new(SessionId(11), 555, players.clone(), build_dice_game_rules());
    for _ in 0..8 {
        let current = original.current_player();
        original
            .process_command(current, Box::new(RollDiceCommand { player: current }))
            .unwrap();
    }

    let log_bytes = original.export_log().unwrap();
    let (_replayed, all_events) = Session::replay_collecting_events(
        SessionId(11),
        555,
        players,
        build_dice_game_rules(),
        &log_bytes,
    )
    .expect("reproduce y junta eventos");

    // Verificar que existen eventos SecretNoteEvent en la partida
    let has_secret_notes = all_events
        .iter()
        .any(|e| e.as_any().downcast_ref::<SecretNoteEvent>().is_some());
    assert!(
        has_secret_notes,
        "debe haber eventos privados SecretNoteEvent en la partida"
    );

    let spectator_view = filter_events_for_spectator(&all_events, spectator);

    for event in &spectator_view {
        assert!(
            event.as_any().downcast_ref::<SecretNoteEvent>().is_none(),
            "un espectador nunca debe recibir un evento privado SecretNoteEvent"
        );
    }
}

#[test]
fn snapshot_restaura_estado_mid_game_sin_reproducir_comandos() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let players = vec![alice, bob];

    let mut session = Session::new(SessionId(12), 999, players, build_dice_game_rules());
    for _ in 0..3 {
        let current = session.current_player();
        session
            .process_command(current, Box::new(RollDiceCommand { player: current }))
            .unwrap();
    }

    let snapshot_bytes = session.snapshot().expect("crea el snapshot");
    let restored = Session::from_snapshot(&snapshot_bytes, build_dice_game_rules())
        .expect("restaura la sesión desde el snapshot");

    assert_eq!(restored.current_tick(), session.current_tick());
    assert_eq!(restored.current_player(), session.current_player());
}

#[test]
fn timestamps_son_monotonicos_entre_comandos_sucesivos() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let players = vec![alice, bob];

    let mut session = Session::new(SessionId(20), 12345, players, build_dice_game_rules());

    for _ in 0..5 {
        std::thread::sleep(std::time::Duration::from_millis(2));
        let current = session.current_player();
        session
            .process_command(current, Box::new(RollDiceCommand { player: current }))
            .unwrap();
    }

    let timestamps = session.tick_timestamps();
    assert_eq!(timestamps.len(), 5, "debe haber 5 timestamps registrados");

    for window in timestamps.windows(2) {
        let (tick1, time1) = window[0];
        let (tick2, time2) = window[1];
        assert!(tick2 > tick1, "el tick debe ser strictly creciente");
        assert!(
            time2 >= time1,
            "el timestamp debe ser monótonamente creciente ({} >= {})",
            time2,
            time1
        );
    }
}

#[test]
fn comando_extra_despues_de_game_over_es_rechazado_con_game_already_over() {
    let alice = PlayerId(1);
    let mut rules = RuleEngine::new();

    #[derive(Debug, Clone, Serialize, Deserialize)]
    struct EndGameCommand {
        player: PlayerId,
    }

    #[typetag::serde]
    impl Command for EndGameCommand {
        fn clone_box(&self) -> Box<dyn Command> {
            Box::new(self.clone())
        }

        fn issuer(&self) -> Option<PlayerId> {
            Some(self.player)
        }
        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    }

    #[derive(Debug, Serialize, Deserialize)]
    struct GameOverEvent;

    #[typetag::serde]
    impl Event for GameOverEvent {
        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    }

    rules.register::<EndGameCommand, _>(|_cmd, world| {
        world.insert_resource(GameOverResource(true));
        Ok(vec![Box::new(GameOverEvent)])
    });

    let mut session = Session::new(SessionId(30), 100, vec![alice], rules);

    // Primer comando termina la partida
    let result = session.process_command(alice, Box::new(EndGameCommand { player: alice }));
    assert!(
        result.is_ok(),
        "el primer comando debe procesarse correctamente"
    );

    // Segundo comando debe ser rechazado
    let extra_result = session.process_command(alice, Box::new(EndGameCommand { player: alice }));
    assert!(
        matches!(extra_result, Err(EngineError::GameAlreadyOver)),
        "comando adicional debe devolve GameAlreadyOver"
    );
}

#[test]
fn intento_de_cargar_archivo_inexistente_retorna_io_error() {
    let result = Session::load_from_file(
        SessionId(99),
        123,
        vec![PlayerId(1)],
        build_dice_game_rules(),
        "ruta_de_archivo_completamente_inexistente_12345.json",
    );

    assert!(
        matches!(result, Err(EngineError::IoError(_))),
        "cargar un archivo inexistente debe retornar EngineError::IoError"
    );
}

#[test]
fn test_game_variant_recuperacion_correcta() {
    let alice = PlayerId(1);
    let variant = GameVariant::Custom("SpeedDice".to_string());
    let session = Session::new_with_variant(
        SessionId(101),
        42,
        vec![alice],
        build_dice_game_rules(),
        variant.clone(),
    );

    let retrieved = session.world().resource::<GameVariantResource>();
    assert_eq!(retrieved.0, variant);
}

#[test]
fn test_on_event_handler_se_invoca_en_cada_evento() {
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    let alice = PlayerId(1);
    let mut session = Session::new(SessionId(102), 42, vec![alice], build_dice_game_rules());

    let count = Arc::new(AtomicUsize::new(0));
    let count_clone = count.clone();

    session.on_event::<DiceRolledEvent>(move |_event| {
        count_clone.fetch_add(1, Ordering::SeqCst);
    });

    session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .unwrap();
    session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .unwrap();

    assert_eq!(count.load(Ordering::SeqCst), 2);
}

#[test]
fn test_rate_limit_rechaza_comandos_excesivos() {
    let alice = PlayerId(1);
    let mut session = Session::new(SessionId(103), 42, vec![alice], build_dice_game_rules());

    session.set_rate_limit(2);

    assert!(session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .is_ok());
    assert!(session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .is_ok());

    let result = session.process_command(alice, Box::new(RollDiceCommand { player: alice }));
    assert!(
        matches!(result, Err(EngineError::RateLimitExceeded(p)) if p == alice),
        "el tercer comando debe ser rechazado por rate limit"
    );
}

#[test]
fn test_metadata_contiene_nombre_del_juego_correcto() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let players = vec![alice, bob];

    let session = Session::new_with_metadata(
        SessionId(104),
        "Dado Mágico",
        42,
        players.clone(),
        build_dice_game_rules(),
    );

    let meta = session.metadata();
    assert_eq!(meta.game_name, "Dado Mágico");
    assert_eq!(meta.max_players, 2);
    assert!(meta.started_at > 0);
}

#[test]
fn test_replay_parcial_desde_tick_3_produce_estado_correcto() {
    let alice = PlayerId(1);
    let mut original = Session::new(SessionId(105), 100, vec![alice], build_dice_game_rules());

    for _ in 0..5 {
        original
            .process_command(alice, Box::new(RollDiceCommand { player: alice }))
            .unwrap();
    }

    assert_eq!(original.current_tick(), Tick(5));
    let log_bytes = original.export_log().unwrap();

    let mut replay_session =
        Session::new(SessionId(105), 100, vec![alice], build_dice_game_rules());
    // Reproducimos los primeros 3 comandos para dejar la sesión en tick 3
    for _ in 0..3 {
        replay_session
            .process_command(alice, Box::new(RollDiceCommand { player: alice }))
            .unwrap();
    }
    assert_eq!(replay_session.current_tick(), Tick(3));

    // Ahora reproducimos parcialmente los comandos con tick > 3 (ticks 4 y 5)
    let partial_events = replay_session.replay_from(&log_bytes, Tick(3)).unwrap();
    assert_eq!(replay_session.current_tick(), Tick(5));
    assert!(!partial_events.is_empty());
}

#[test]
fn test_into_result_contiene_datos_correctos_de_partida() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);
    let mut session = Session::new_with_metadata(
        SessionId(200),
        "DiceGame",
        42,
        vec![alice, bob],
        build_dice_game_rules(),
    );

    session
        .world_mut()
        .insert_resource(WinnerResource(Some(alice)));

    session
        .process_command(alice, Box::new(RollDiceCommand { player: alice }))
        .unwrap();

    let result = session.into_result(1500);

    assert_eq!(result.winner, Some(alice));
    assert_eq!(result.duration_ms, 1500);
    assert_eq!(result.total_moves, 1);
    assert_eq!(result.players, vec![alice, bob]);
    assert_eq!(result.game_name, "DiceGame");
}

#[derive(Debug, Serialize, Deserialize)]
struct GroupMessageEvent {
    group: Vec<PlayerId>,
    text: String,
}

#[typetag::serde]
impl Event for GroupMessageEvent {
    fn visibility(&self) -> Visibility {
        Visibility::PrivateToGroup(self.group.clone())
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[test]
fn test_private_to_group_llega_solo_a_los_jugadores_del_grupo() {
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);
    let p3 = PlayerId(3);

    let event: Box<dyn Event> = Box::new(GroupMessageEvent {
        group: vec![p1, p2],
        text: "Mensaje secreto de grupo".to_string(),
    });
    let events: Vec<Box<dyn Event>> = vec![event];

    let p1_events = filter_events_for_player(&events, p1);
    let p2_events = filter_events_for_player(&events, p2);
    let p3_events = filter_events_for_player(&events, p3);

    assert_eq!(
        p1_events.len(),
        1,
        "P1 está en el grupo y debe recibir el evento"
    );
    assert_eq!(
        p2_events.len(),
        1,
        "P2 está en el grupo y debe recibir el evento"
    );
    assert_eq!(
        p3_events.len(),
        0,
        "P3 NO está en el grupo y NO debe recibir el evento"
    );
}
