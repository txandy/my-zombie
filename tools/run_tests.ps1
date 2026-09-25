# Ejecuta la suite de gdUnit4 en headless.
# Uso: $env:GODOT_BIN = "C:\ruta\godot_console.exe"; tools\run_tests.ps1 [-a res://tests/ruta]
# Sin argumentos ejecuta todo res://tests.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not $env:GODOT_BIN) {
    Write-Error "Define GODOT_BIN con la ruta al ejecutable de Godot $(Get-Content .godot-version)."
    exit 1
}

New-Item -ItemType Directory -Force reports | Out-Null
New-Item -ItemType File -Force reports/.gdignore | Out-Null

# Importa recursos y registra class_name antes de ejecutar los tests.
& $env:GODOT_BIN --headless --path . --import *> $null

$testArgs = if ($args.Count -gt 0) { $args } else { @("-a", "res://tests") }

& $env:GODOT_BIN --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 `
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c @testArgs
$code = $LASTEXITCODE
& $env:GODOT_BIN --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd @testArgs *> $null
Write-Host "Tests terminados con código $code"
exit $code
