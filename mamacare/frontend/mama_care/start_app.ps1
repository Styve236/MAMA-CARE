[CmdletBinding()]
param(
  [string]$Device = 'chrome',
  [int]$PreferredPort = 3000,
  [switch]$NoWebResourcesCdn
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$logRoot = Join-Path $projectRoot '.dart-run'
$stdoutLog = Join-Path $logRoot 'backend.stdout.log'
$stderrLog = Join-Path $logRoot 'backend.stderr.log'

New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Test-PortAvailable([int]$Port) {
  $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  return $null -eq $connection
}

$port = $PreferredPort
while (-not (Test-PortAvailable $port) -and $port -lt ($PreferredPort + 100)) {
  $port++
}

if (-not (Test-PortAvailable $port)) {
  throw "Aucun port disponible entre $PreferredPort et $($PreferredPort + 99)."
}

if ($Device -eq 'emulator-5554' -or $Device -like 'android*') {
  $apiHost = '10.0.2.2'
} else {
  $apiHost = 'localhost'
}

$previousPort = $env:PORT
$env:PORT = $port.ToString()
$backendProcess = $null

try {
  Write-Host "Démarrage du backend sur http://$apiHost`:$port ..."
  $backendProcess = Start-Process `
    -FilePath 'dart' `
    -ArgumentList @('run', 'bin/server.dart') `
    -WorkingDirectory $backendRoot `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru

  $healthUrl = "http://localhost:$port/health"
  $ready = $false
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    Start-Sleep -Milliseconds 500
    try {
      $health = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
      if ($health.StatusCode -eq 200) {
        $ready = $true
        break
      }
    } catch {
      if ($backendProcess.HasExited) {
        break
      }
    }
  }

  if (-not $ready) {
    $backendError = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw } else { '' }
    throw "Le backend n'est pas devenu disponible sur $healthUrl.`n$backendError"
  }

  $apiUrl = "http://$apiHost`:$port"
  Write-Host "Backend prêt: $healthUrl"
  Write-Host "Lancement Flutter ($Device) avec API_BASE_URL=$apiUrl"

  $flutterArguments = @('run', '-d', $Device, "--dart-define=API_BASE_URL=$apiUrl")
  if ($Device -eq 'chrome' -and $NoWebResourcesCdn) {
    $flutterArguments += '--no-web-resources-cdn'
  }

  Push-Location $projectRoot
  try {
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
} finally {
  if ($backendProcess -and -not $backendProcess.HasExited) {
    Write-Host 'Arrêt du backend...'
    Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
  }

  if ($null -eq $previousPort) {
    Remove-Item Env:PORT -ErrorAction SilentlyContinue
  } else {
    $env:PORT = $previousPort
  }
}
