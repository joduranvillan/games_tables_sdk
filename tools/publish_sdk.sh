#!/usr/bin/env bash
set -euo pipefail
cargo publish -p open_table_core
sleep 30  # esperar propagación a crates.io
cargo publish -p open_table_macros
sleep 30
cargo publish -p open_table_engine
echo "SDK published successfully"
