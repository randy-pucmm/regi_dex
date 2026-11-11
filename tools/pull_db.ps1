# Baja las bases SQLite de RegiDex desde el dispositivo Android a tools/db/
# (git-ignorado) para abrirlas en DB Browser for SQLite, VS Code, etc.:
#   - regidex.sqlite      datos y sync_metadata (Drift)
#   - regidex_images.db   indice de la cache de imagenes (flutter_cache_manager)
#
# Uso:
#   .\tools\pull_db.ps1                         # un solo dispositivo conectado
#   .\tools\pull_db.ps1 -Device 192.168.25.13:34181
#   .\tools\pull_db.ps1 -Open                   # abre la carpeta al terminar
#
# Requiere una build debug (run-as) y adb en el PATH.

param(
  [string]$Device,
  [string]$Package = 'com.example.regi_dex',
  [switch]$Open
)

$ErrorActionPreference = 'Stop'

$outDir = Join-Path $PSScriptRoot 'db'

# Nombre local -> ruta dentro del directorio privado de la app.
$databases = [ordered]@{
  'regidex.sqlite'    = 'app_flutter/regidex.sqlite'
  'regidex_images.db' = 'files/regidex_images.db'
}

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

$sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
if (-not $sqlite) {
  $candidate = Join-Path (Split-Path (Get-Command adb).Source) 'sqlite3.exe'
  if (Test-Path $candidate) { $sqlite = $candidate }
}

$pulled = 0
foreach ($entry in $databases.GetEnumerator()) {
  $name = $entry.Key
  $main = Join-Path $outDir $name

  # cmd /c: el redireccionamiento de PowerShell 5.1 corrompe datos binarios.
  foreach ($suffix in '', '-wal', '-shm') {
    $target = "$main$suffix"
    Remove-Item $target -ErrorAction SilentlyContinue
    cmd /c "adb -s $Device exec-out run-as $Package cat $($entry.Value)$suffix > `"$target`" 2>nul"
    # Si el archivo no existe, run-as escribe su error en la salida: se descarta
    # lo que no empiece con la cabecera de SQLite.
    if (Test-Path $target) {
      $item = Get-Item $target
      $header = if ($item.Length -ge 15) {
        [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($target)[0..14])
      } else { '' }
      if ($suffix -eq '' -and $header -ne 'SQLite format 3') { Remove-Item $target }
      elseif ($suffix -ne '') {
        $head = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($target), 0, [math]::Min(200, $item.Length))
        if ($item.Length -eq 0 -or $head -match 'No such file') { Remove-Item $target }
      }
    }
  }

  if (-not (Test-Path $main)) {
    Write-Warning "No se pudo leer $name (no existe aun, o la app no esta en modo debug)."
    continue
  }

  # Con la app abierta, los ultimos cambios pueden estar en el WAL: se funden en
  # el archivo principal para que quede autocontenido.
  if ($sqlite) {
    & $sqlite $main 'PRAGMA wal_checkpoint(TRUNCATE);' | Out-Null
    Remove-Item "$main-wal", "$main-shm" -ErrorAction SilentlyContinue
  } elseif (Test-Path "$main-wal") {
    Write-Warning 'sqlite3 no encontrado: se dejan los archivos -wal/-shm junto a la base.'
  }

  $size = [math]::Round((Get-Item $main).Length / 1KB)
  Write-Host "Listo: $main ($size KB)"
  $pulled++
}

if ($pulled -eq 0) {
  throw "No se pudo bajar ninguna base. Esta instalada la app ($Package) en modo debug y abierta al menos una vez?"
}

if ($Open) { Invoke-Item $outDir }
