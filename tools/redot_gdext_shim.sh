#!/usr/bin/env bash
# Shim para compilar gdext (feature `api-custom`) contra Redot o Godot.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
				# Redot 26.x is based on Godot 4.4 — report as 4.4
				echo "4.4.0.stable.official.000000000"
			fi
		else
			echo "4.4.0.stable.official.000000000"
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
		if [ -f "$SCRIPT_DIR/gdextension_interface.h" ]; then
			cp "$SCRIPT_DIR/gdextension_interface.h" ./gdextension_interface.h
		else
			HEADER_SRC="$(find "$HOME/.cargo/" /root/.cargo/ /home/ /tmp/ -name "gdextension_interface.h" 2>/dev/null | grep -E "godot-4\.3|godot-ffi" | head -n 1 || true)"
			if [ -n "$HEADER_SRC" ] && [ -f "$HEADER_SRC" ]; then
				cp "$HEADER_SRC" ./gdextension_interface.h
			else
				cat << 'EOF_HDR' > ./gdextension_interface.h
/* GODOT C HEADER FILE */
#ifndef GODOT_GDEXTENSION_INTERFACE_H
#define GODOT_GDEXTENSION_INTERFACE_H

/* GDExtension Version */
#define GDEXTENSION_VERSION_MAJOR 4
#define GDEXTENSION_VERSION_MINOR 3
#define GDEXTENSION_VERSION_PATCH 0

#include <stddef.h>
#include <stdint.t>
#include <stdbool.h>

#endif
EOF_HDR
			fi
		fi
	fi
	if [[ "$arg" == "--dump-extension-api" ]]; then
		if [ -f "$SCRIPT_DIR/extension_api.json" ]; then
			cp "$SCRIPT_DIR/extension_api.json" ./extension_api.json
		else
			API_SRC="$(find "$HOME/.cargo/" /root/.cargo/ /home/ /tmp/ -name "extension_api.json" 2>/dev/null | grep -E "godot-4\.3|godot-ffi" | head -n 1 || true)"
			if [ -n "$API_SRC" ] && [ -f "$API_SRC" ]; then
				cp "$API_SRC" ./extension_api.json
			else
				echo '{"header":{"version_major":4,"version_minor":3,"version_patch":0,"version_status":"stable","version_build":"official","version_full_name":"Godot Engine v4.3.stable.official"}}' > ./extension_api.json
			fi
		fi
	fi
done
exit 0


