#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== GENERANDO RESUMEN DE CAMBIOS DESDE ULTIMO TAG ==="

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LATEST_TAG" ]; then
    echo "Último tag encontrado: $LATEST_TAG"
    RANGE="$LATEST_TAG..HEAD"
else
    echo "No se encontraron tags. Extrayendo todos los commits..."
    RANGE="HEAD"
fi

echo ""
echo "## [Unreleased]"
echo ""

FEATS=$(git log $RANGE --oneline --grep="^feat" || true)
FIXES=$(git log $RANGE --oneline --grep="^fix" || true)
DOCS=$(git log $RANGE --oneline --grep="^docs" || true)
OTHERS=$(git log $RANGE --oneline --invert-grep --grep="^feat" --grep="^fix" --grep="^docs" || true)

if [ -n "$FEATS" ]; then
    echo "### Added / Features"
    echo "$FEATS" | sed 's/^[a-f0-9]* /- /'
    echo ""
fi

if [ -n "$FIXES" ]; then
    echo "### Fixed"
    echo "$FIXES" | sed 's/^[a-f0-9]* /- /'
    echo ""
fi

if [ -n "$DOCS" ]; then
    echo "### Documentation"
    echo "$DOCS" | sed 's/^[a-f0-9]* /- /'
    echo ""
fi

if [ -n "$OTHERS" ]; then
    echo "### Other Changes"
    echo "$OTHERS" | sed 's/^[a-f0-9]* /- /'
    echo ""
fi
