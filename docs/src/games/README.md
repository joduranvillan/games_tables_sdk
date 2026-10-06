# Included Board Games

OpenTable SDK ships with **13 ready-to-play deterministic board games**, each implemented as an independent Rust crate and paired with a dedicated Godot scene and smoke test:

| Game | Crate | Players | AI Engine | Notation / Export |
| :--- | :--- | :---: | :--- | :--- |
| [Chess](./chess.md) | `chess_game` | 2 | Minimax α-β + ECO Opening Book | PGN / FEN |
| [Checkers](./checkers.md) | `checkers_game` | 2 | Minimax α-β | PDN |
| [Go](./go.md) | `go_game` | 2 | MCTS (Rollouts by `AiDifficulty`) | SGF |
| [Shogi](./shogi.md) | `shogi_game` | 2 | Minimax α-β + Hand Drops | KIF / SFEN |
| [Xiangqi](./xiangqi.md) | `xiangqi_game` | 2 | Minimax α-β | WXon / FEN |
| [Backgammon](./backgammon.md) | `backgammon_game` | 2 | Expectiminimax / Heuristic | Match Log |
| [Ludo](./ludo.md) | `ludo_game` | 2–4 | Heuristic Priority | JSON Replay |
| [Uno](./uno.md) | `uno_game` | 2–4 | Hidden-Info Card AI | JSON Replay |
| [Monopoly](./monopoly.md) | `monopoly_game` | 2–4 | Economic Evaluator | JSON Replay |
| [Crisis](./crisis.md) | `crisis_game` | 2–4 | Risk/Liquidity Heuristic | JSON Replay |
| [Mille Bornes](./mille_bornes.md) | `mille_bornes_game` | 2–4 | Hazard/Distance Heuristic | JSON Replay |
| [Chinese Checkers](./chinese_checkers.md) | `chinese_checkers_game` | 2–6 | Hop-Chain Search | JSON Replay |
| [Battleship](./battleship.md) | `battleship_game` | 2 | Hunt/Target Probability Grid | JSON Replay |
