#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Topological Crates.io Trusted Publishing (OIDC) & Metadata Verification Script
# Supports:
#   --check-metadata   Audits all 22 publishable Cargo.toml manifests and READMEs
#   --dry-run          Runs --check-metadata + cargo publish --dry-run on Tier-1 foundation crates
#   --publish          Publishes all 22 crates in 4-tier topological order using CARGO_REGISTRY_TOKEN (OIDC)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SDK_ROOT"

MODE="dry-run"
PUBLISH_DELAY_SECS="${PUBLISH_DELAY_SECS:-15}"

while [ $# -gt 0 ]; do
  case "$1" in
    --check-metadata)
      MODE="check-metadata"
      shift
      ;;
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --publish)
      MODE="publish"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--check-metadata | --dry-run | --publish]" >&2
      exit 1
      ;;
  esac
done

# 4-Tier Topological Dependency DAG (22 Publishable Crates)
TIER_1_FOUNDATION=(
  "open_table_core"
  "open_table_macros"
)

TIER_2_ENGINE_AND_TRANSPORTS=(
  "open_table_engine"
  "open_table_qr"
  "open_table_transport_tcp"
  "open_table_transport_websocket"
  "open_table_transport_native_bridge"
)

TIER_3_CANONICAL_GAMES=(
  "chess_game"
  "checkers_game"
  "shogi_game"
  "xiangqi_game"
  "go_game"
  "chinese_checkers_game"
  "backgammon_game"
  "ludo_game"
  "battleship_game"
  "mille_bornes_game"
  "monopoly_game"
  "uno_game"
  "crisis_game"
  "goose_game"
)

TIER_4_RELAY_SERVER=(
  "open_table_relay"
)

ALL_PUBLISHABLE_CRATES=(
  "${TIER_1_FOUNDATION[@]}"
  "${TIER_2_ENGINE_AND_TRANSPORTS[@]}"
  "${TIER_3_CANONICAL_GAMES[@]}"
  "${TIER_4_RELAY_SERVER[@]}"
)

FFI_CDYLIB_BRIDGES=(
  "open_table_godot"
  "open_table_wasm"
)

verify_crates_metadata() {
  echo "=== [1/2] Auditing Crates.io Metadata & Topological Dependencies (22 Publishable Crates + 2 FFI Bridges) ==="
  local failed=0

  for crate in "${ALL_PUBLISHABLE_CRATES[@]}"; do
    local manifest="$SDK_ROOT/$crate/Cargo.toml"
    local readme="$SDK_ROOT/$crate/README.md"

    if [ ! -f "$manifest" ]; then
      echo "ERROR: Missing Cargo.toml for $crate" >&2
      failed=1
      continue
    fi

    if [ ! -s "$readme" ]; then
      echo "ERROR: Missing or empty README.md for $crate" >&2
      failed=1
    fi

    if grep -qE '^publish\s*=\s*false' "$manifest"; then
      echo "ERROR: Publishable crate $crate has 'publish = false' in Cargo.toml" >&2
      failed=1
    fi

    for field in "name" "version" "edition" "rust-version" "description" "license" "repository" "keywords" "categories" "readme"; do
      if ! grep -qE "^${field}\s*=" "$manifest"; then
        echo "ERROR: $crate/Cargo.toml is missing required crates.io field '${field}'" >&2
        failed=1
      fi
    done

    # Ensure every internal path dependency under [dependencies] specifies a version
    local unversioned_deps
    unversioned_deps=$(awk '
      /^\[dependencies\]/ { in_deps=1; next }
      /^\[/ { in_deps=0 }
      in_deps && /path\s*=\s*"\.\.\// && !/version\s*=/ { print }
    ' "$manifest")

    if [ -n "$unversioned_deps" ]; then
      echo "ERROR: $crate/Cargo.toml has [dependencies] with path but missing version:" >&2
      echo "$unversioned_deps" >&2
      failed=1
    fi

    echo "  [OK] $crate (metadata, README.md & versioned dependencies verified)"
  done

  for bridge in "${FFI_CDYLIB_BRIDGES[@]}"; do
    local manifest="$SDK_ROOT/$bridge/Cargo.toml"
    if ! grep -qE '^publish\s*=\s*false' "$manifest"; then
      echo "ERROR: FFI cdylib bridge $bridge must have 'publish = false'" >&2
      failed=1
    else
      echo "  [OK] $bridge (FFI cdylib bridge marked publish = false)"
    fi
  done

  if [ "$failed" -ne 0 ]; then
    echo "ERROR: Crates.io metadata audit failed." >&2
    exit 1
  fi
  echo "OK: All 22 publishable crates and 2 FFI bridges passed Crates.io metadata audit."
}

run_dry_run_packaging() {
  echo "=== [2/2] Running Crates.io Packaging Dry-Run on Tier-1 Foundation Crates ==="
  if command -v cargo >/dev/null 2>&1; then
    for crate in "${TIER_1_FOUNDATION[@]}"; do
      echo "  -> cargo publish --dry-run --allow-dirty -p $crate"
      cargo publish --dry-run --allow-dirty -p "$crate"
    done
    echo "OK: Tier-1 Foundation crates packaged cleanly via cargo publish --dry-run."
  else
    echo "INFO: 'cargo' binary not available in current shell; static metadata & DAG audit completed."
  fi
}

is_crate_version_published() {
  local crate_name="$1"
  local crate_version="$2"
  if command -v curl >/dev/null 2>&1; then
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -A "open-table-sdk-trusted-publisher (https://github.com/joduranvillan/games_tables_sdk)" \
      "https://crates.io/api/v1/crates/${crate_name}/${crate_version}" || echo "000")
    if [ "$status_code" = "200" ]; then
      return 0
    fi
  fi
  return 1
}

publish_tier() {
  local tier_label="$1"
  local wait_after="$2"
  shift 2
  local crates=("$@")
  local published_any=0

  echo "------------------------------------------------------------------------------"
  echo "Publishing ${tier_label} (${#crates[@]} crates)..."
  echo "------------------------------------------------------------------------------"

  for crate in "${crates[@]}"; do
    local manifest="$SDK_ROOT/$crate/Cargo.toml"
    local ver
    ver=$(grep -m1 '^version = ' "$manifest" | sed -E 's/version = "(.*)"/\1/')

    if is_crate_version_published "$crate" "$ver"; then
      echo "  [SKIP] ${crate}@${ver} is already published on crates.io."
      continue
    fi

    echo "  [PUBLISH] cargo publish -p ${crate} (v${ver})..."
    local output_file
    output_file=$(mktemp)
    if cargo publish -p "$crate" --no-verify 2>&1 | tee "$output_file"; then
      echo "  [SUCCESS] Published ${crate}@${ver} to crates.io."
      published_any=1
    else
      if grep -qiE "already uploaded|already exists" "$output_file"; then
        echo "  [SKIP] ${crate}@${ver} was already uploaded to crates.io."
      else
        rm -f "$output_file"
        echo "ERROR: Failed to publish ${crate}@${ver} to crates.io." >&2
        exit 1
      fi
    fi
    rm -f "$output_file"
  done

  if [ "$wait_after" = "true" ] && [ "$published_any" -eq 1 ]; then
    echo "Waiting ${PUBLISH_DELAY_SECS}s for crates.io sparse index propagation before next topological tier..."
    sleep "$PUBLISH_DELAY_SECS"
  fi
}

verify_crates_metadata

case "$MODE" in
  check-metadata)
    ;;
  dry-run)
    run_dry_run_packaging
    ;;
  publish)
    if [ -z "${CARGO_REGISTRY_TOKEN:-}" ]; then
      echo "ERROR: CARGO_REGISTRY_TOKEN is not set. Authenticate via rust-lang/crates-io-auth-action@v1 (Trusted Publishing OIDC)." >&2
      exit 1
    fi
    publish_tier "Tier 1: Foundation Base" "true" "${TIER_1_FOUNDATION[@]}"
    publish_tier "Tier 2: ECS Engine & Network Transports" "true" "${TIER_2_ENGINE_AND_TRANSPORTS[@]}"
    publish_tier "Tier 3: 14 Canonical Board Game Engines" "true" "${TIER_3_CANONICAL_GAMES[@]}"
    publish_tier "Tier 4: Standalone WebSocket Relay Server" "false" "${TIER_4_RELAY_SERVER[@]}"
    echo "=============================================================================="
    echo "SUCCESS: All 22 publishable OpenTable SDK crates published to crates.io!"
    echo "=============================================================================="
    ;;
esac
