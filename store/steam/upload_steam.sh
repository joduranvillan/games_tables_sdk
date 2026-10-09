#!/usr/bin/env bash
set -euo pipefail

STEAM_USER="${STEAM_USER:-anonymous}"

steamcmd +login "$STEAM_USER" +run_app_build "$PWD/store/steam/app_build.vdf" +quit
