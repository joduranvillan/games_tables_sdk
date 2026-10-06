# OpenTable — 13 Classic Board Games & Deterministic Tabletop SDK

**OpenTable** is a cross-platform tabletop game collection and deterministic Rust game engine (`bevy_ecs` + Godot/Redot GDExtension).

## 🎲 13 Playable Games Included
1. **Chess** — Full FIDE rules + PGN/FEN export & opening practice.
2. **Go (19×19)** — Liberty/capture rules, Ko rule & SGF export.
3. **Shogi (9×9)** — Drops, promotions, Nifu & Uchifuzume rules.
4. **Xiangqi (9×10)** — Palace, River, Cannon & Flying General rules.
5. **Checkers (8×8)** — Mandatory captures & multi-jump chains.
6. **Chinese Checkers** — 121-node star board with chain hops.
7. **Backgammon** — Bar, Bearing Off & Doubling Cube (2..64).
8. **Battleship** — Fleet deployment & tactical salvo grid.
9. **Ludo** — 4-player race with safe zones and captures.
10. **Mille Bornes** — Hazards, remedies, safeties & Coup-Fourré.
11. **Monopoly** — Properties, houses/hotels, auctions & mortgages.
12. **Uno** — Action cards, Wild +4 & colorblind geometric icons.
13. **Crisis / TEG** — 30 territories, 6 continents & secret objectives.

## ✨ Features
- **Offline AI & Pass-and-Play**: 3 AI difficulty levels (Easy, Medium, Hard Minimax with Alpha-Beta pruning).
- **Cross-Platform Multiplayer**: LAN TCP, WebSocket Relay rooms (6-character codes), and mobile P2P.
- **Accessibility & Controls**: Gamepad / Steam Deck virtual cursor reticle, touch pinch-to-zoom, 4 languages (EN/ES/PT/FR), and colorblind patterns.
- **Developer SDK**: Copy `addons/open_table/` into your own Godot 4 / Redot project to build custom deterministic board games in Rust.
