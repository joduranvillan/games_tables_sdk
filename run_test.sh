#!/bin/bash
# Corre el test host/cliente TCP en foreground con timeout estricto.
#
# Nota: `test_tcp_bridge.tscn` no llama a quit() (es una escena interactiva,
# no un SceneTree script como tests/bridge_smoke.gd), así que SIEMPRE termina
# por timeout, nunca solo. Antes esto se corría en background con `sleep 10`
# + `pkill -f`, lo cual podía dejar el proceso de Redot corriendo indefinidamente
# si el pkill no matcheaba (causó un freeze de la máquina). `timeout -k` en
# foreground garantiza SIGKILL si el proceso no responde a SIGTERM.
cd /home/jodv/Desarrollo/games_tables_sdk/godot_project

timeout -k 5 30 redot --headless --path . test_tcp_bridge.tscn > /tmp/test_output.log 2>&1
exit_code=$?

echo "=== TEST OUTPUT ==="
grep -E "\[|✅|❌|🟡|🏆|ERROR|error" /tmp/test_output.log | head -50

if [ "$exit_code" -eq 124 ] || [ "$exit_code" -eq 137 ]; then
	echo "(terminado por timeout, esperado: la escena no se cierra sola)"
fi
