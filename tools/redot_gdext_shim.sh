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

set -e

find_godot_bin() {
	if [ -n "${REDOT_BIN:-}" ] && [ -x "$REDOT_BIN" ]; then
		echo "$REDOT_BIN"
		return 0
	fi
	if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
		echo "$GODOT_BIN"
		return 0
	fi
	for bin in redot godot4 godot /usr/bin/redot /usr/bin/godot /usr/local/bin/godot; do
		if command -v "$bin" >/dev/null 2>&1; then
			command -v "$bin"
			return 0
		elif [ -x "$bin" ]; then
			echo "$bin"
			return 0
		fi
	done
	return 1
}

REAL_BIN="$(find_godot_bin || true)"

for arg in "$@"; do
	if [[ "$arg" == "--version" ]]; then
		if [ -n "$REAL_BIN" ]; then
			VER="$("$REAL_BIN" --version 2>/dev/null || echo "")"
			if [[ "$VER" =~ ^4\. ]]; then
				echo "$VER"
			else
				echo "4.3.0.stable.official.000000000"
			fi
		else
			echo "4.3.0.stable.official.000000000"
		fi
		exit 0
	fi
done

if [ -n "$REAL_BIN" ]; then
	exec "$REAL_BIN" "$@"
fi

# Fallback cuando no hay un binario de Godot/Redot instalado en el sistema
for arg in "$@"; do
	if [[ "$arg" == "--dump-gdextension-interface" ]]; then
		HEADER_SRC="$(find "$HOME/.cargo/registry/src/" /root/.cargo/registry/src/ /home/*/.cargo/registry/src/ -name "gdextension_interface.h" 2>/dev/null | grep "godot-4.3/gdextension_interface.h" | head -n 1 || true)"
		if [ -n "$HEADER_SRC" ] && [ -f "$HEADER_SRC" ]; then
			cp "$HEADER_SRC" ./gdextension_interface.h
		else
			touch ./gdextension_interface.h
		fi
	fi
	if [[ "$arg" == "--dump-extension-api" ]]; then
		API_SRC="$(find "$HOME/.cargo/registry/src/" /root/.cargo/registry/src/ /home/*/.cargo/registry/src/ -name "extension_api.json" 2>/dev/null | grep "godot-4.3/extension_api.json" | head -n 1 || true)"
		if [ -n "$API_SRC" ] && [ -f "$API_SRC" ]; then
			cp "$API_SRC" ./extension_api.json
		else
			echo "{}" > ./extension_api.json
		fi
	fi
done
exit 0

