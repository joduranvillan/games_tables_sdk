#!/usr/bin/env bash
# Shim para compilar gdext (feature `api-custom`) contra Redot o Godot.
#
# gdext exige que `--version` reporte un Godot de major 4. Redot reporta
# "26.x" en su branding, aunque INTERNAMENTE es compatible con Godot 4.
#
# Este shim detecta si el binario del sistema es Redot o Godot. Si es Godot 4,
# devuelve su versión nativa; si es Redot, simula la versión Godot 4.x para
# pasar el chequeo inicial de gdext, y delega el resto de comandos (--dump-extension-api)
# al binario real.

set -euo pipefail

REAL_BIN="${REDOT_BIN:-${GODOT_BIN:-$(command -v redot || command -v godot4 || command -v godot || echo /usr/bin/redot)}}"

for arg in "$@"; do
	if [[ "$arg" == "--version" ]]; then
		VER="$("$REAL_BIN" --version 2>/dev/null || echo "")"
		if [[ "$VER" =~ ^4\. ]]; then
			echo "$VER"
		else
			echo "4.5.2.stable.custom_build.5f54c0dc5"
		fi
		exit 0
	fi
done

exec "$REAL_BIN" "$@"
