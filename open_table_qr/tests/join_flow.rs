// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::ids::SessionId;
use open_table_core::random::RandomService;
use open_table_qr::{generate_join_code, generate_join_qr_svg, parse_join_payload, JoinPayload};

#[test]
fn el_codigo_de_invitacion_es_determinista_con_la_misma_seed() {
    let mut rng_a = RandomService::from_seed(999);
    let mut rng_b = RandomService::from_seed(999);

    let code_a = generate_join_code(&mut rng_a);
    let code_b = generate_join_code(&mut rng_b);

    assert_eq!(code_a, code_b);
    assert_eq!(code_a.chars().count(), 6);
}

#[test]
fn el_codigo_de_invitacion_no_usa_caracteres_ambiguos() {
    let mut rng = RandomService::from_seed(1);
    for _ in 0..50 {
        let code = generate_join_code(&mut rng);
        for c in code.chars() {
            assert!(
                !['0', 'O', '1', 'I'].contains(&c),
                "el código '{code}' contiene un caracter ambiguo: '{c}'"
            );
        }
    }
}

#[test]
fn el_qr_generado_es_un_svg_valido_y_decodifica_al_mismo_payload() {
    let mut rng = RandomService::from_seed(42);
    let join_code = generate_join_code(&mut rng);

    let payload = JoinPayload {
        session_id: SessionId(7),
        join_code: join_code.clone(),
        host_name: "Mesa de Alice".to_string(),
        game_type: "dice_game".to_string(),
    };

    let svg = generate_join_qr_svg(&payload).expect("genera el QR");

    assert!(svg.contains("<svg"), "debe contener un elemento <svg>");
    assert!(svg.contains("viewBox"), "el SVG del QR debe tener viewBox");

    // Simula lo que hace el cliente: escanea, obtiene el JSON, lo parsea.
    let json = serde_json::to_string(&payload).unwrap();
    let decoded = parse_join_payload(&json).expect("decodifica el payload escaneado");

    assert_eq!(decoded, payload);
    assert_eq!(decoded.join_code, join_code);
}

#[test]
fn el_qr_lan_incluye_ip_puerto_y_se_extrae_desde_svg() {
    let payload = open_table_qr::LanJoinPayload {
        session_id: SessionId(1),
        join_code: "K7M9P2".to_string(),
        host_name: "HostOffline".to_string(),
        game_type: "goose".to_string(),
        ip: "192.168.1.42".to_string(),
        port: 9090,
    };

    let svg = open_table_qr::generate_lan_join_qr_svg(&payload).expect("genera QR LAN");
    assert!(svg.contains("<svg"));

    let extracted = open_table_qr::extract_qr_payload_json(&svg).expect("extrae JSON del SVG");
    let decoded =
        open_table_qr::parse_lan_join_payload(&extracted).expect("decodifica payload LAN");
    assert_eq!(decoded, payload);
    assert_eq!(decoded.ip, "192.168.1.42");
    assert_eq!(decoded.port, 9090);
    assert_eq!(decoded.game_type, "goose");
}
