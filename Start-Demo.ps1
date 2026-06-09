# ============================================================
# ScholiLink - One-Click Local Demo Launcher (Windows PowerShell)
# ============================================================
# By default this script overwrites assets\.env and functions\.env with the
# committed *.env.demo templates so FIREBASE_PROJECT_ID matches the Auth
# emulator seed (see docs/INSTALL.md). Use -KeepExistingEnv to preserve
# existing files (only if you know they are already demo-aligned).
# ============================================================

param(
  [switch]$KeepExistingEnv
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
  Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
  Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Assert-Command([string]$CommandName, [string]$Hint) {
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    Write-Fail "$CommandName not found. $Hint"
    exit 1
  }
}

Write-Step "Checking prerequisites..."
Assert-Command "flutter"  "Install Flutter >= 3.38.4: https://docs.flutter.dev/get-started/install"
Assert-Command "node"     "Install Node.js 22: https://nodejs.org/en/download"
Assert-Command "npm"      "Comes with Node.js."
Assert-Command "firebase" "Run: npm install -g firebase-tools"
Assert-Command "java"     "Install JDK 21+: https://adoptium.net"

$nodeVer = (node -v) -replace 'v', ''
$nodeMajor = [int]($nodeVer.Split('.')[0])
if ($nodeMajor -lt 22) {
  Write-Host "  [WARN] Node.js $nodeVer detected; Cloud Functions require Node 22." -ForegroundColor Yellow
} else {
  Write-Ok "Node.js $nodeVer"
}

$flutterVersionJson = flutter --version --machine 2>$null | ConvertFrom-Json
Write-Ok ("Flutter " + $flutterVersionJson.frameworkVersion)
$javaOut = cmd /c "java -version 2>&1" | Select-Object -First 1
Write-Ok ("Java: " + $javaOut)

Write-Step "Installing Flutter dependencies..."
Set-Location $RepoRoot
flutter pub get

Write-Step "Installing Cloud Functions dependencies..."
Set-Location "$RepoRoot\functions"
npm ci --silent
Set-Location $RepoRoot

Write-Step "Configuring environment files (demo templates)..."
$assetEnv = "$RepoRoot\assets\.env"
$functionsEnv = "$RepoRoot\functions\.env"

if ($KeepExistingEnv) {
  if (-not (Test-Path $assetEnv)) {
    if (Test-Path "$RepoRoot\assets\.env.demo") {
      Copy-Item "$RepoRoot\assets\.env.demo" $assetEnv
      Write-Ok "Created assets\.env from .env.demo"
    } else {
      Copy-Item "$RepoRoot\assets\.env.example" $assetEnv
      Write-Ok "Created assets\.env from .env.example"
    }
  } else {
    Write-Ok "Keeping existing assets\.env (-KeepExistingEnv)."
  }
  if (-not (Test-Path $functionsEnv)) {
    if (Test-Path "$RepoRoot\functions\.env.demo") {
      Copy-Item "$RepoRoot\functions\.env.demo" $functionsEnv
      Write-Ok "Created functions\.env from .env.demo"
    } else {
      Copy-Item "$RepoRoot\functions\.env.example" $functionsEnv
      Write-Ok "Created functions\.env from .env.example"
    }
  } else {
    Write-Ok "Keeping existing functions\.env (-KeepExistingEnv)."
  }
} else {
  if (Test-Path "$RepoRoot\assets\.env.demo") {
    Copy-Item "$RepoRoot\assets\.env.demo" $assetEnv -Force
    Write-Ok "Synced assets\.env from .env.demo (matches Auth emulator seed project)."
  } elseif (-not (Test-Path $assetEnv)) {
    Copy-Item "$RepoRoot\assets\.env.example" $assetEnv
    Write-Ok "Created assets\.env from .env.example (.env.demo missing)."
  } else {
    Write-Ok "assets\.env.demo missing; left existing assets\.env in place."
  }
  if (Test-Path "$RepoRoot\functions\.env.demo") {
    Copy-Item "$RepoRoot\functions\.env.demo" $functionsEnv -Force
    Write-Ok "Synced functions\.env from .env.demo"
  } elseif (-not (Test-Path $functionsEnv)) {
    Copy-Item "$RepoRoot\functions\.env.example" $functionsEnv
    Write-Ok "Created functions\.env from .env.example (.env.demo missing)."
  } else {
    Write-Ok "functions\.env.demo missing; left existing functions\.env in place."
  }
}

Write-Step "Starting Firebase emulators (new window)..."
$emulatorCmd = "Set-Location '$RepoRoot\functions'; npm run emulators; Read-Host 'Press Enter to close'"
Start-Process powershell -ArgumentList @("-NoExit", "-Command", $emulatorCmd) -WindowStyle Normal

$maxWaitSeconds = 120
Write-Step "Waiting for Firestore emulator on port 8080..."
$waited = 0
$ready = $false
while ($waited -lt $maxWaitSeconds) {
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:8080" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
    if ($null -ne $response -and $response.StatusCode -lt 500) {
      $ready = $true
      break
    }
  } catch {
    # Keep waiting until timeout.
  }

  Start-Sleep -Seconds 2
  $waited += 2
  Write-Host ("  Waiting for Firestore... (" + $waited + "/" + $maxWaitSeconds + " s)") -ForegroundColor DarkGray
}

if (-not $ready) {
  Write-Fail "Firestore (8080) did not become ready. Check the emulator PowerShell window for Java/port errors, or free port 8080."
  exit 1
}
Write-Ok "Firestore emulator is ready."

Write-Step "Waiting for Auth emulator on port 9099 (often starts after Firestore)..."
$authReady = $false
$authWaited = 0
while ($authWaited -lt $maxWaitSeconds) {
  $tcp = New-Object System.Net.Sockets.TcpClient
  try {
    $tcp.Connect('127.0.0.1', 9099)
    $authReady = $true
    $tcp.Close()
    break
  } catch {
    if ($null -ne $tcp) { $tcp.Dispose() }
    Start-Sleep -Seconds 2
    $authWaited += 2
    Write-Host ("  Waiting for Auth... (" + $authWaited + "/" + $maxWaitSeconds + " s)") -ForegroundColor DarkGray
  }
}
if (-not $authReady) {
  Write-Fail "Auth emulator (9099) did not accept connections. Demo users cannot be seeded. Check the emulator window: fix any crash, or free port 9099 (see docs/INSTALL.md)."
  exit 1
}
Write-Ok "Auth emulator is ready."
Write-Host "  (Brief settle before seed...)" -ForegroundColor DarkGray
Start-Sleep -Seconds 5

Write-Step "Seeding demo users and data..."
Set-Location "$RepoRoot\functions"
node scripts/seed-local.js
$seedExitCode = $LASTEXITCODE
Set-Location $RepoRoot
if ($seedExitCode -ne 0) {
  Write-Fail "Seed script failed (exit code $seedExitCode). Demo accounts were not created. After emulators show 'All emulators ready', run: cd functions; npm run seed:local"
  exit 1
}
Write-Ok "Seed complete. Login: student@example.com / Passw0rd!"

Write-Step "Detecting Flutter run target..."
$devicesJson = flutter devices --machine 2>$null | ConvertFrom-Json
$target = $null

$chrome = $devicesJson | Where-Object { $_.id -match 'chrome' -or $_.sdk -match 'Chrome' } | Select-Object -First 1
if ($null -ne $chrome) {
  $target = $chrome.id
  Write-Ok ("Selected target: Chrome (" + $target + ")")
} elseif ($devicesJson.Count -gt 0) {
  $target = $devicesJson[0].id
  Write-Ok ("Selected target: " + $devicesJson[0].name + " (" + $target + ")")
} else {
  Write-Host "  [WARN] No Flutter devices found. Flutter will prompt you." -ForegroundColor Yellow
}

Write-Step "Launching Flutter app against local emulators..."
$flutterArgs = @("run", "--dart-define=USE_LOCAL_EMULATORS=true")
if ($null -ne $target -and $target -ne "") {
  $flutterArgs += @("-d", $target)
}
& flutter @flutterArgs
