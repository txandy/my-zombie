#!/usr/bin/env bash
# Ejecuta la suite de gdUnit4 en headless.
# Uso: GODOT_BIN=/ruta/a/godot tools/run_tests.sh [-a res://tests/ruta]
# Sin argumentos ejecuta todo res://tests.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -z "${GODOT_BIN:-}" ]; then
	echo "Define GODOT_BIN con la ruta al ejecutable de Godot $(cat .godot-version)." >&2
	exit 1
fi

mkdir -p reports && : > reports/.gdignore

# Importa recursos y registra class_name antes de ejecutar los tests.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

args=("$@")
if [ ${#args[@]} -eq 0 ]; then
	args=(-a res://tests)
fi

exec bash addons/gdUnit4/runtest.sh --godot_binary "$GODOT_BIN" --headless --ignoreHeadlessMode -c "${args[@]}"
