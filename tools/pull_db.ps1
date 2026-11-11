# Baja la base SQLite de RegiDex desde el dispositivo Android a tools/db/regidex.sqlite
# (git-ignorado) para abrirla en DB Browser for SQLite, VS Code, etc.
#
# Uso:
#   .\tools\pull_db.ps1                         # un solo dispositivo conectado
#   .\tools\pull_db.ps1 -Device 192.168.25.13:34181
#   .\tools\pull_db.ps1 -Open                   # abre el archivo al terminar
#
# Requiere una build debug (run-as) y adb en el PATH.

param(
  [string]$Device,
  [string]$Package = 'com.example.regi_dex',
  [switch]$Open
)

$ErrorActionPreference = 'Stop'

$outDir = Join-Path $PSScriptRoot 'db'
$outFile = Join-Path $outDir 'regidex.sqlite'
$remoteDir = 'app_flutter'

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  throw 'adb no esta en el PATH (Android SDK platform-tools).'
}

if (-not $Device) {
  $devices = @(adb devices | Select-Object -Skip 1 |
    Where-Object { $_ -match '\tdevice$' } |
    ForEach-Object { ($_ -split '\t')[0] })
  if ($devices.Count -eq 0) { throw 'No hay dispositivos conectados (adb devices).' }
  # Un mismo telefono puede salir varias veces (USB, TCP, mDNS): se usa el primero.
  $Device = $devices[0]
  if ($devices.Count -gt 1) { Write-Host "Varios dispositivos; usando $Device" }
}

New-Item -ItemType Directory -Force $outDir | Out-Null

# cmd /c: el redireccionamiento de PowerShell 5.1 corrompe datos binarios.
foreach ($suffix in '', '-wal', '-shm') {
  $name = "regidex.sqlite$suffix"
  $target = Join-Path $outDir $name
  Remove-Item $target -ErrorAction SilentlyContinue
  cmd /c "adb -s $Device exec-out run-as $Package cat $remoteDir/$name > `"$target`" 2>nul"
  if ((Test-Path $target) -and (Get-Item $target).Length -eq 0) {
    Remove-Item $target
  }
}

if (-not (Test-Path $outFile)) {
  throw "No se pudo leer la base. Esta instalada la app ($Package) en modo debug y abierta al menos una vez?"
}

# Con la app abierta, los ultimos cambios pueden estar en el WAL: se funden en el
# archivo principal para que quede autocontenido.
$sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
if (-not $sqlite) {
  $adbDir = Split-Path (Get-Command adb).Source
  $candidate = Join-Path $adbDir 'sqlite3.exe'
  if (Test-Path $candidate) { $sqlite = $candidate }
}
if ($sqlite) {
  & $sqlite $outFile 'PRAGMA wal_checkpoint(TRUNCATE);' | Out-Null
  Remove-Item (Join-Path $outDir 'regidex.sqlite-wal'), (Join-Path $outDir 'regidex.sqlite-shm') -ErrorAction SilentlyContinue
} else {
  Write-Warning 'sqlite3 no encontrado: se dejan los archivos -wal/-shm junto a la base.'
}

$size = [math]::Round((Get-Item $outFile).Length / 1KB)
Write-Host "Listo: $outFile ($size KB)"

if ($Open) { Invoke-Item $outFile }
