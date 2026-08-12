use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct DummyCommand {
    player: PlayerId,
    counter: u32,
}

#[typetag::serde]
impl Command for DummyCommand {
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
struct DummyEvent {
    counter: u32,
}

#[typetag::serde]
impl Event for DummyEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[derive(bevy_ecs::system::Resource, Clone, Debug, PartialEq, Eq)]
struct StateResource {
    pub value: u32,
    pub version: u32,
}

fn build_dummy_rules(version: u32) -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.register::<DummyCommand, _>(move |cmd, world| {
        let mut state = world.get_resource_or_insert_with(|| StateResource { value: 0, version });
        state.value += cmd.counter;
        state.version = version;
        Ok(vec![Box::new(DummyEvent {
            counter: state.value,
        })])
    });
    rules
}

#[test]
fn test_export_log_comprimido_es_menor_que_el_original() {
    let p1 = PlayerId(1);
    let players = vec![p1];
    let rules = build_dummy_rules(1);
    let mut session = Session::new(SessionId(100), 12345, players, rules);

    for i in 0..120 {
        let _ = session.process_command(
            p1,
            Box::new(DummyCommand {
                player: p1,
                counter: i,
            }),
        );
    }

    let uncompressed = session.export_log().expect("export_log falló");
    let compressed = session
        .export_log_compressed()
        .expect("export_log_compressed falló");

    // El tamaño comprimido debe ser al menos 50% menor para logs de 100+ movimientos.
    assert!(
        compressed.len() * 2 <= uncompressed.len(),
        "El tamaño comprimido ({}) no es al menos 50% menor que el original ({})",
        compressed.len(),
        uncompressed.len()
    );
}

#[test]
fn test_replay_desde_log_comprimido_produce_estado_correcto() {
    let p1 = PlayerId(1);
    let players = vec![p1];
    let rules = build_dummy_rules(1);
    let mut session = Session::new(SessionId(101), 42, players.clone(), rules);

    for i in 1..=20 {
        session
            .process_command(
                p1,
                Box::new(DummyCommand {
                    player: p1,
                    counter: i,
                }),
            )
            .unwrap();
    }

    let compressed = session
        .export_log_compressed()
        .expect("export_log_compressed falló");

    // Replay usando replay_from_compressed en una nueva sesión
    let rules_for_replay = build_dummy_rules(1);
    let mut new_session = Session::new(SessionId(102), 42, players.clone(), rules_for_replay);
    new_session
        .replay_from_compressed(&compressed)
        .expect("replay_from_compressed falló");

    assert_eq!(new_session.current_tick(), session.current_tick());
    assert_eq!(new_session.command_log().len(), session.command_log().len());

    let state_orig = session.world().get_resource::<StateResource>().unwrap();
    let state_new = new_session.world().get_resource::<StateResource>().unwrap();
    assert_eq!(state_orig, state_new);

    // Replay usando el método estático replay_compressed
    let rules_for_static_replay = build_dummy_rules(1);
    let reconstructed = Session::replay_compressed(
        SessionId(103),
        42,
        players,
        rules_for_static_replay,
        &compressed,
    )
    .expect("replay_compressed estático falló");

    assert_eq!(reconstructed.current_tick(), session.current_tick());
    let state_recon = reconstructed
        .world()
        .get_resource::<StateResource>()
        .unwrap();
    assert_eq!(state_orig, state_recon);
}

#[test]
fn test_log_signed_firma_valida_e_invalida() {
    let p1 = PlayerId(1);
    let players = vec![p1];
    let rules = build_dummy_rules(1);
    let mut session = Session::new(SessionId(104), 100, players, rules);

    for i in 1..=5 {
        session
            .process_command(
                p1,
                Box::new(DummyCommand {
                    player: p1,
                    counter: i,
                }),
            )
            .unwrap();
    }

    let secret = b"super_secret_tournament_key";
    let signed_log = session
        .export_log_signed(secret)
        .expect("export_log_signed falló");

    // Firma válida debe ser aceptada por verify_log
    assert!(
        Session::verify_log(&signed_log, secret).is_ok(),
        "verify_log debería haber tenido éxito con firma válida"
    );

    // Clave incorrecta debe fallar
    let wrong_secret = b"wrong_secret_key_1234567";
    assert!(
        Session::verify_log(&signed_log, wrong_secret).is_err(),
        "verify_log debería fallar con clave incorrecta"
    );

    // Manipulación del log (alterar 1 byte del payload JSON) debe fallar
    let mut tampered_log = signed_log.clone();
    if !tampered_log.is_empty() {
        tampered_log[0] ^= 0xFF;
    }
    assert!(
        Session::verify_log(&tampered_log, secret).is_err(),
        "verify_log debería fallar con log manipulado"
    );
}

#[test]
fn test_hot_reload_de_reglas_preserva_el_estado_del_mundo() {
    let p1 = PlayerId(1);
    let players = vec![p1];
    let rules_v1 = build_dummy_rules(1);
    let rules_v2 = build_dummy_rules(2);

    let mut session = Session::new(SessionId(105), 777, players, rules_v1);

    // Aplicar comando en V1
    session
        .process_command(
            p1,
            Box::new(DummyCommand {
                player: p1,
                counter: 10,
            }),
        )
        .unwrap();

    let state_before = session
        .world()
        .get_resource::<StateResource>()
        .unwrap()
        .clone();
    assert_eq!(state_before.value, 10);
    assert_eq!(state_before.version, 1);

    // Intentar swap sin pausar la sesión debe fallar
    let swap_unpaused_res = session.swap_rule_engine(rules_v2);
    assert!(
        swap_unpaused_res.is_err(),
        "swap_rule_engine debe fallar si la sesión no está pausada"
    );

    // Pausar y realizar swap exitoso
    session.pause().unwrap();
    assert!(session.is_paused());

    let rules_v2_fresh = build_dummy_rules(2);
    session
        .swap_rule_engine(rules_v2_fresh)
        .expect("swap_rule_engine falló en estado pausado");

    // El estado del mundo se preserva
    let state_during_pause = session
        .world()
        .get_resource::<StateResource>()
        .unwrap()
        .clone();
    assert_eq!(state_during_pause.value, 10);
    assert_eq!(state_during_pause.version, 1);

    // Reanudar la sesión y procesar comando con las reglas V2
    session.resume().unwrap();
    assert!(!session.is_paused());

    session
        .process_command(
            p1,
            Box::new(DummyCommand {
                player: p1,
                counter: 5,
            }),
        )
        .unwrap();

    let state_after = session.world().get_resource::<StateResource>().unwrap();
    assert_eq!(state_after.value, 15);
    assert_eq!(state_after.version, 2);
}
