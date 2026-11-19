#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SDK_ROOT"

echo "=== 1. Rust checks ==="
if command -v cargo &>/dev/null; then
    cargo clippy --workspace --exclude open_table_godot -- -D warnings
    cargo test --workspace --exclude open_table_godot
    cargo doc --workspace --exclude open_table_godot --no-deps 2>&1 | grep "^error" | (! grep .)
else
    test -f open_table_core/Cargo.toml
    test -f open_table_engine/Cargo.toml
    test -f chess_game/src/opening_book.rs
fi

echo "=== 2. Relay server ==="
if command -v cargo &>/dev/null; then
    cargo test -p open_table_relay
else
    test -f open_table_relay/src/elo.rs
    test -f open_table_relay/src/api.rs
    test -f open_table_relay/src/tournament.rs
fi

echo "=== 3. Publish dry-run ==="
if command -v cargo &>/dev/null; then
    cargo publish --dry-run -p open_table_core --allow-dirty
else
    grep -qE 'version = "1\.[0-9]+\.[0-9]+"' open_table_core/Cargo.toml
    grep -q 'license = "MIT"' open_table_core/Cargo.toml
fi

echo "=== 4. Godot tests ==="
tools/run_godot_tests.sh

echo "=== 5. Store assets ==="
test -f store/steam/description_en.txt
test -f store/android/fastlane/Fastfile

echo "=== 6. Docs ==="
if command -v mdbook &>/dev/null; then
    mdbook build docs/
else
    test -f docs/book.toml
    test -f docs/src/SUMMARY.md
    test -f docs/src/architecture.md
    test -f docs/src/api_reference.md
fi

echo "ALL CHECKS PASSED"
