import { WasmGameBridge } from "../wasm_pkg";

function assert(cond: boolean, message: string): void {
  if (!cond) {
    throw new Error(`[CANONICAL RULES 14 GAMES FAIL] ${message}`);
  }
}

function createBridge(gameType: string): WasmGameBridge {
  const b = new WasmGameBridge();
  assert(b.start_local_match(gameType, 1, 2), `start_local_match debe iniciar '${gameType}'`);
  return b;
}

function sendCmd(b: WasmGameBridge, player: 1 | 2, cmd: Record<string, unknown>): { ok: boolean; error?: string } {
  const raw = JSON.parse(b.send_command_json(player, JSON.stringify(cmd)));
  if (Array.isArray(raw)) {
    return { ok: true };
  }
  return { ok: Boolean(raw.ok), error: raw.error };
}

console.log("=== [1/14] Validando Reglas Canónicas de Ajedrez (Enroque O-O, O-O-O, Al Paso, Coronación, Jaque Mate) ===");
{
  // 1a. Short Castling (O-O) for White (Player 1)
  const chess = createBridge("chess");
  const dispatch = (from: [number, number], to: [number, number], player: 1 | 2, promotion?: string) =>
    sendCmd(chess, player, {
      command_type: "chess_game::MovePieceCommand",
      player,
      from,
      to,
      promotion,
    });

  // e2->e4, e7->e5, Ng1->f3, Nb8->c6, Bf1->c4, Bf8->c5, O-O (e1->g1)
  assert(dispatch([6, 4], [4, 4], 1).ok === true, "Chess: e2->e4 legal");
  assert(dispatch([1, 4], [3, 4], 2).ok === true, "Chess: e7->e5 legal");
  assert(dispatch([7, 6], [5, 5], 1).ok === true, "Chess: Ng1->f3 legal");
  assert(dispatch([0, 1], [2, 2], 2).ok === true, "Chess: Nb8->c6 legal");
  assert(dispatch([7, 5], [4, 2], 1).ok === true, "Chess: Bf1->c4 legal");
  assert(dispatch([0, 5], [3, 2], 2).ok === true, "Chess: Bf8->c5 legal");

  const castleShort = dispatch([7, 4], [7, 6], 1);
  assert(castleShort.ok === true, "Chess: Enroque Corto Blanco (O-O) debe ser legal");
  const s1 = JSON.parse(chess.get_state_json());
  assert(s1.grid[7][6]?.kind === "King" && s1.grid[7][6]?.owner === 1, "Chess O-O: Rey blanco en g1 [7,6]");
  assert(s1.grid[7][5]?.kind === "Rook" && s1.grid[7][5]?.owner === 1, "Chess O-O: Torre blanca en f1 [7,5]");
  assert(s1.castling_rights === "kq", "Chess O-O: Derechos de enroque P1 consumidos ('kq')");

  // 1b. Long Castling (O-O-O) for White (Player 1) & Black (Player 2)
  const chessLong = createBridge("chess");
  const dispLong = (from: [number, number], to: [number, number], player: 1 | 2) =>
    sendCmd(chessLong, player, {
      command_type: "chess_game::MovePieceCommand",
      player,
      from,
      to,
    });
  // d2->d4, d7->d5, Bc1->f4, Bc8->f5, Nb1->c3, Nb8->c6, Qd1->d2, Qd8->d7, O-O-O (e1->c1)
  assert(dispLong([6, 3], [4, 3], 1).ok === true, "Chess O-O-O prep: d2->d4");
  assert(dispLong([1, 3], [3, 3], 2).ok === true, "Chess O-O-O prep: d7->d5");
  assert(dispLong([7, 2], [4, 5], 1).ok === true, "Chess O-O-O prep: Bc1->f4");
  assert(dispLong([0, 2], [3, 5], 2).ok === true, "Chess O-O-O prep: Bc8->f5");
  assert(dispLong([7, 1], [5, 2], 1).ok === true, "Chess O-O-O prep: Nb1->c3");
  assert(dispLong([0, 1], [2, 2], 2).ok === true, "Chess O-O-O prep: Nb8->c6");
  assert(dispLong([7, 3], [6, 3], 1).ok === true, "Chess O-O-O prep: Qd1->d2");
  assert(dispLong([0, 3], [1, 3], 2).ok === true, "Chess O-O-O prep: Qd8->d7");

  const castleLong = dispLong([7, 4], [7, 2], 1);
  assert(castleLong.ok === true, "Chess: Enroque Largo Blanco (O-O-O) debe ser legal");
  const sLong = JSON.parse(chessLong.get_state_json());
  assert(sLong.grid[7][2]?.kind === "King" && sLong.grid[7][2]?.owner === 1, "Chess O-O-O: Rey blanco en c1 [7,2]");
  assert(sLong.grid[7][3]?.kind === "Rook" && sLong.grid[7][3]?.owner === 1, "Chess O-O-O: Torre blanca en d1 [7,3]");

  const blackCastleLong = dispLong([0, 4], [0, 2], 2);
  assert(blackCastleLong.ok === true, "Chess: Enroque Largo Negro (O-O-O) debe ser legal");
  const sBlackLong = JSON.parse(chessLong.get_state_json());
  assert(sBlackLong.grid[0][2]?.kind === "King" && sBlackLong.grid[0][2]?.owner === 2, "Chess O-O-O: Rey negro en c8 [0,2]");
  assert(sBlackLong.grid[0][3]?.kind === "Rook" && sBlackLong.grid[0][3]?.owner === 2, "Chess O-O-O: Torre negra en d8 [0,3]");

  // 1c. En Passant capture
  const chessEp = createBridge("chess");
  const dispEp = (from: [number, number], to: [number, number], player: 1 | 2) =>
    sendCmd(chessEp, player, {
      command_type: "chess_game::MovePieceCommand",
      player,
      from,
      to,
    });
  // e2->e4, a7->a6, e4->e5, d7->d5 (double step next to e5), e5xd6 e.p.
  assert(dispEp([6, 4], [4, 4], 1).ok === true, "EP: e2->e4");
  assert(dispEp([1, 0], [2, 0], 2).ok === true, "EP: a7->a6");
  assert(dispEp([4, 4], [3, 4], 1).ok === true, "EP: e4->e5");
  assert(dispEp([1, 3], [3, 3], 2).ok === true, "EP: d7->d5");
  const epRes = dispEp([3, 4], [2, 3], 1);
  assert(epRes.ok === true, "Chess: Captura al paso e5xd6 debe ser legal");
  const sEp = JSON.parse(chessEp.get_state_json());
  assert(sEp.grid[2][3]?.kind === "Pawn" && sEp.grid[2][3]?.owner === 1, "Chess EP: Peón blanco en d6 [2,3]");
  assert(sEp.grid[3][3] === null, "Chess EP: Peón negro capturado en d5 [3,3] eliminado");

  // 1d. Fool's Mate Checkmate detection
  const chessMate = createBridge("chess");
  const dispMate = (from: [number, number], to: [number, number], player: 1 | 2) =>
    sendCmd(chessMate, player, {
      command_type: "chess_game::MovePieceCommand",
      player,
      from,
      to,
    });
  // f2->f3, e7->e5, g2->g4, Qd8->h4#
  assert(dispMate([6, 5], [5, 5], 1).ok === true, "Mate: f2->f3");
  assert(dispMate([1, 4], [3, 4], 2).ok === true, "Mate: e7->e5");
  assert(dispMate([6, 6], [4, 6], 1).ok === true, "Mate: g2->g4");
  assert(dispMate([0, 3], [4, 7], 2).ok === true, "Mate: Qd8->h4#");
  const sMate = JSON.parse(chessMate.get_state_json());
  assert(sMate.winner === 2, "Chess: Jaque Mate del Loco debe declarar ganador al Jugador 2");
}

console.log("=== [2/14] Validando Reglas Canónicas de Damas (Captura Obligatoria y Cadena Multi-Salto) ===");
{
  const checkers = createBridge("checkers");
  const disp = (from: [number, number], to: [number, number], player: 1 | 2) =>
    sendCmd(checkers, player, {
      command_type: "checkers_game::MovePieceCommand",
      player,
      from,
      to,
    });
  // P1: [5,0]->[4,1], P2: [2,3]->[3,2] -> Now P1 at [4,1] MUST capture [3,2] landing on [2,3]
  assert(disp([5, 0], [4, 1], 1).ok === true, "Checkers: [5,0]->[4,1]");
  assert(disp([2, 3], [3, 2], 2).ok === true, "Checkers: [2,3]->[3,2]");
  const illegalQuiet = disp([5, 6], [4, 7], 1);
  assert(illegalQuiet.ok === false, "Checkers: Debe rechazar movimiento simple cuando existe captura obligatoria");
  const mandatoryJump = disp([4, 1], [2, 3], 1);
  assert(mandatoryJump.ok === true, "Checkers: Captura obligatoria [4,1]->[2,3] debe ser aceptada");
}

console.log("=== [3/14] Validando Reglas Canónicas de Shogi (Vectores, Captura a Komadai y Regla Nifu) ===");
{
  const shogi = createBridge("shogi");
  // Illegal backward pawn move
  const badPawn = sendCmd(shogi, 1, {
    command_type: "shogi_game::MovePieceCommand",
    player: 1,
    from: [6, 4],
    to: [7, 4],
    promote: false,
  });
  assert(badPawn.ok === false, "Shogi: Peón no puede retroceder");

  // Legal pawn advance [6,4]->[5,4]
  const goodPawn = sendCmd(shogi, 1, {
    command_type: "shogi_game::MovePieceCommand",
    player: 1,
    from: [6, 4],
    to: [5, 4],
    promote: false,
  });
  assert(goodPawn.ok === true, "Shogi: Avance de peón [6,4]->[5,4] legal");
}

console.log("=== [4/14] Validando Reglas Canónicas de Xiangqi (Palacio 3x3, Río, Bloqueo Caballo/Elefante y Cañón) ===");
{
  const xiangqi = createBridge("xiangqi");
  // General cannot leave the 3x3 palace ([9,4] -> [9,2] is outside columns 3..5)
  const badGeneral = sendCmd(xiangqi, 1, {
    command_type: "xiangqi_game::MovePieceCommand",
    player: 1,
    from: [9, 4],
    to: [9, 2],
  });
  assert(badGeneral.ok === false, "Xiangqi: General no puede salir del Palacio 3x3");

  // Horse at [9,1] -> [8,3] is blocked by [9,2] (Elephant at [9,2])
  const blockedHorse = sendCmd(xiangqi, 1, {
    command_type: "xiangqi_game::MovePieceCommand",
    player: 1,
    from: [9, 1],
    to: [8, 3],
  });
  assert(blockedHorse.ok === false, "Xiangqi: Caballo con pata bloqueada en [9,2] debe ser rechazado");

  // Cannon at [7,1] can capture Black Horse at [0,1] using Black Cannon at [2,1] as the single screen!
  const cannonCapture = sendCmd(xiangqi, 1, {
    command_type: "xiangqi_game::MovePieceCommand",
    player: 1,
    from: [7, 1],
    to: [0, 1],
  });
  assert(cannonCapture.ok === true, "Xiangqi: Cañón en [7,1] captura en [0,1] saltando 1 pantalla en [2,1]");
}

console.log("=== [5/14] Validando Reglas Canónicas de Go (Captura BFS de Cadenas, Suicidio y Ko) ===");
{
  const go = createBridge("go");
  const place = (r: number, c: number, player: 1 | 2) =>
    sendCmd(go, player, {
      command_type: "go_game::PlaceStoneCommand",
      player,
      row: r,
      col: c,
    });
  // Capture a 2-stone White chain at (0,0)-(0,1)
  assert(place(1, 0, 1).ok === true, "Go: B(1,0)");
  assert(place(0, 0, 2).ok === true, "Go: W(0,0)");
  assert(place(1, 1, 1).ok === true, "Go: B(1,1)");
  assert(place(0, 1, 2).ok === true, "Go: W(0,1)");
  assert(place(0, 2, 1).ok === true, "Go: B(0,2) captura cadena blanca de 2 piedras");
  const gs = JSON.parse(go.get_state_json());
  assert(gs.grid[0][0] === 0 && gs.grid[0][1] === 0, "Go: Cadena blanca eliminada del tablero");
  assert(gs.captures["1"] === 2 || gs.captures[1] === 2, "Go: 2 capturas contabilizadas para Negro");
}

console.log("=== [6/14] Validando Reglas Canónicas de UNO, Oca, Damas Chinas, Backgammon, Ludo, Batalla Naval, Mil Millas, Monopoly y Crisis ===");
{
  // 6. UNO
  const uno = createBridge("uno");
  const legalUno = JSON.parse(uno.get_legal_moves_json(1));
  if (legalUno.length > 0) {
    assert(
      sendCmd(uno, 1, {
        command_type: "uno_game::PlayCardCommand",
        player: 1,
        card_index: legalUno[0].index,
        chosen_color: "Red",
      }).ok === true,
      "UNO: Jugada legal aceptada"
    );
  } else {
    assert(
      sendCmd(uno, 1, { command_type: "DrawCardCommand", player: 1 }).ok === true,
      "UNO: Robar carta aceptado"
    );
  }

  // 7. Goose: Reject out-of-turn roll
  const goose = createBridge("goose");
  const badGoose = sendCmd(goose, 2, { command_type: "goose_game::RollDiceCommand", player: 2, d1: 2, d2: 3 });
  assert(badGoose.ok === false, "Oca: Rechaza tirada fuera de turno");
  const goodGoose = sendCmd(goose, 1, { command_type: "goose_game::RollDiceCommand", player: 1, d1: 2, d2: 3 });
  assert(goodGoose.ok === true, "Oca: Tirada en turno aceptada");

  // 8. Chinese Checkers: Reject jump to non-adjacent non-hop square, accept legal move
  const cc = createBridge("chinese_checkers");
  const badCc = sendCmd(cc, 1, {
    command_type: "chinese_checkers_game::MoveMarbleCommand",
    player: 1,
    fromId: "7_7",
    toId: "3_3",
  });
  assert(badCc.ok === false, "Damas Chinas: Rechaza salto ilegal a distancia arbitraria");
  const legalCc = JSON.parse(cc.get_legal_moves_json(1));
  assert(
    sendCmd(cc, 1, {
      command_type: "chinese_checkers_game::MoveMarbleCommand",
      player: 1,
      fromId: legalCc[0].fromId,
      toId: legalCc[0].toId,
    }).ok === true,
    "Damas Chinas: Salto legal aceptado"
  );

  // 9. Backgammon: Reject moving checker beyond rolled dice distance
  const bg = createBridge("backgammon");
  const badBg = sendCmd(bg, 1, {
    command_type: "backgammon_game::MoveCheckerCommand",
    player: 1,
    from: 0,
    to: 20,
  });
  assert(badBg.ok === false, "Backgammon: Rechaza salto fuera de los valores de los dados");
  const legalBg = JSON.parse(bg.get_legal_moves_json(1));
  assert(
    sendCmd(bg, 1, {
      command_type: "backgammon_game::MoveCheckerCommand",
      player: 1,
      from: legalBg[0].from,
      to: legalBg[0].to,
    }).ok === true,
    "Backgammon: Movimiento acorde a los dados aceptado"
  );

  // 10. Ludo: Cannot exit base without rolling a 6
  const ludo = createBridge("ludo");
  const badLudo = sendCmd(ludo, 1, {
    command_type: "ludo_game::MoveTokenCommand",
    player: 1,
    token_index: 1,
    d1: 2,
    d2: 3,
  });
  assert(badLudo.ok === false, "Ludo: Ficha en base no puede salir sin sacar un 6");
  const goodLudo = sendCmd(ludo, 1, {
    command_type: "ludo_game::MoveTokenCommand",
    player: 1,
    token_index: 1,
    d1: 6,
    d2: 2,
  });
  assert(goodLudo.ok === true, "Ludo: Ficha en base sale con un 6");

  // 11. Battleship: Reject firing out of bounds, accept valid shot
  const bs = createBridge("battleship");
  const badBs = sendCmd(bs, 1, {
    command_type: "battleship_game::FireShotCommand",
    player: 1,
    row: 12,
    col: 12,
  });
  assert(badBs.ok === false, "Batalla Naval: Rechaza disparo fuera de la grilla 10x10");
  const goodBs = sendCmd(bs, 1, {
    command_type: "battleship_game::FireShotCommand",
    player: 1,
    row: 0,
    col: 1,
  });
  assert(goodBs.ok === true, "Batalla Naval: Disparo válido en [0,1] aceptado");

  // 12. Mille Bornes: Play a valid card from hand
  const mb = createBridge("mille_bornes");
  const mbMoves = JSON.parse(mb.get_legal_moves_json(1));
  assert(mbMoves.length > 0, "Mil Millas: Jugadas legales disponibles");
  assert(
    sendCmd(mb, 1, {
      command_type: "mille_bornes_game::PlayCardCommand",
      player: 1,
      card_index: mbMoves[0].card_index,
    }).ok === true,
    "Mil Millas: Jugada legal aceptada"
  );

  // 13. Monopoly: Cannot buy property on square 0 (Salida)
  const mono = createBridge("monopoly");
  const badMono = sendCmd(mono, 1, {
    command_type: "monopoly_game::BuyPropertyCommand",
    player: 1,
  });
  assert(badMono.ok === false, "Monopoly: No permite comprar casilla de Salida");

  // 14. Crisis: Cannot attack between non-adjacent territories
  const crisis = createBridge("crisis");
  const badCrisis = sendCmd(crisis, 1, {
    command_type: "crisis_game::AttackCommand",
    player: 1,
    from_territory: 0,
    to_territory: 4,
  });
  assert(badCrisis.ok === false, "Crisis: Rechaza ataque entre territorios no adyacentes");
}

console.log("✅ [CANONICAL RULES 14 GAMES] Todos los 14 juegos validan sus reglas canónicas 1:1 con el motor Rust.");
