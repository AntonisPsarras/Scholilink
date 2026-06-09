#!/usr/bin/env bash
# ============================================================
# ScholiLink - One-Click Local Demo Launcher (macOS / Linux / WSL)
# ============================================================
# Usage: bash start-demo.sh   [--keep-existing-env]
# Installs deps, syncs demo .env files (by default overwrites so
# FIREBASE_PROJECT_ID matches the Auth emulator seed), starts emulators
# in the background, seeds data, and launches the Flutter app.
# ============================================================

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEEP_EXISTING_ENV=0
for arg in "$@"; do
  case "$arg" in
    --keep-existing-env) KEEP_EXISTING_ENV=1 ;;
  esac
done
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

step()  { echo -e "\n${CYAN}==> $1${NC}"; }
ok()    { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "  ${RED}[FAIL]${NC} $1"; exit 1; }

# ─── Step 1: Prerequisites ────────────────────────────────────
step "Checking prerequisites..."

command -v flutter  >/dev/null 2>&1 || fail "flutter not found. Install: https://docs.flutter.dev/get-started/install"
command -v node     >/dev/null 2>&1 || fail "node not found. Install Node.js 22: https://nodejs.org/en/download"
command -v npm      >/dev/null 2>&1 || fail "npm not found (should come with Node.js)."
command -v firebase >/dev/null 2>&1 || fail "firebase not found. Run: npm install -g firebase-tools"
command -v java     >/dev/null 2>&1 || fail "java not found. Install JDK 21+: https://adoptium.net"

NODE_VER=$(node -v | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 22 ]; then
  warn "Node.js $NODE_VER detected; Cloud Functions require Node 22."
else
  ok "Node.js $NODE_VER"
fi

FLUTTER_VER=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')
ok "Flutter $FLUTTER_VER"
ok "Java: $(java -version 2>&1 | head -1)"

# ─── Step 2: Install dependencies ────────────────────────────
step "Installing Flutter dependencies..."
cd "$REPO_ROOT"
flutter pub get

step "Installing Cloud Functions dependencies..."
cd "$REPO_ROOT/functions"
npm ci --silent
cd "$REPO_ROOT"

# ─── Step 3: Sync demo .env (default: always match Auth seed project) ────
step "Configuring environment files (demo templates)..."

ASSET_ENV="$REPO_ROOT/assets/.env"
FUNC_ENV="$REPO_ROOT/functions/.env"

if [ "$KEEP_EXISTING_ENV" -eq 1 ]; then
  if [ ! -f "$ASSET_ENV" ]; then
    if [ -f "$REPO_ROOT/assets/.env.demo" ]; then
      cp "$REPO_ROOT/assets/.env.demo" "$ASSET_ENV"
      ok "Created assets/.env from .env.demo"
    else
      cp "$REPO_ROOT/assets/.env.example" "$ASSET_ENV"
      ok "Created assets/.env from .env.example"
    fi
  else
    ok "Keeping existing assets/.env (--keep-existing-env)."
  fi
  if [ ! -f "$FUNC_ENV" ]; then
    if [ -f "$REPO_ROOT/functions/.env.demo" ]; then
      cp "$REPO_ROOT/functions/.env.demo" "$FUNC_ENV"
      ok "Created functions/.env from .env.demo"
    else
      cp "$REPO_ROOT/functions/.env.example" "$FUNC_ENV"
      ok "Created functions/.env from .env.example"
    fi
  else
    ok "Keeping existing functions/.env (--keep-existing-env)."
  fi
else
  if [ -f "$REPO_ROOT/assets/.env.demo" ]; then
    cp "$REPO_ROOT/assets/.env.demo" "$ASSET_ENV"
    ok "Synced assets/.env from .env.demo (matches Auth emulator seed project)."
  elif [ ! -f "$ASSET_ENV" ]; then
    cp "$REPO_ROOT/assets/.env.example" "$ASSET_ENV"
    ok "Created assets/.env from .env.example (.env.demo missing)."
  else
    warn "assets/.env.demo missing; left existing assets/.env in place."
  fi
  if [ -f "$REPO_ROOT/functions/.env.demo" ]; then
    cp "$REPO_ROOT/functions/.env.demo" "$FUNC_ENV"
    ok "Synced functions/.env from .env.demo"
  elif [ ! -f "$FUNC_ENV" ]; then
    cp "$REPO_ROOT/functions/.env.example" "$FUNC_ENV"
    ok "Created functions/.env from .env.example (.env.demo missing)."
  else
    warn "functions/.env.demo missing; left existing functions/.env in place."
  fi
fi

# ─── Step 4: Launch emulators in the background ──────────────
step "Starting Firebase emulators (background)..."
cd "$REPO_ROOT/functions"
npm run emulators &>/tmp/scholilink-emulators.log &
EMULATOR_PID=$!
cd "$REPO_ROOT"
ok "Emulators started (PID $EMULATOR_PID). Log: /tmp/scholilink-emulators.log"

# ─── Step 5: Wait for Firestore emulator ─────────────────────
step "Waiting for Firestore emulator on port 8080..."
MAX_WAIT=120
WAITED=0
READY=false
while [ $WAITED -lt $MAX_WAIT ]; do
  if curl -sf --max-time 2 http://127.0.0.1:8080 >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 2
  WAITED=$((WAITED + 2))
  printf "  Waiting for Firestore... (%d/%d s)\r" "$WAITED" "$MAX_WAIT"
done
echo ""
if [ "$READY" != true ]; then
  fail "Firestore (8080) did not become ready. Check /tmp/scholilink-emulators.log or free port 8080."
fi
ok "Firestore emulator is ready."

# ─── Step 5b: Wait for Auth emulator ──────────────────────────
step "Waiting for Auth emulator on port 9099 (often starts after Firestore)..."
AUTH_WAITED=0
AUTH_READY=false
while [ "$AUTH_WAITED" -lt "$MAX_WAIT" ]; do
  if (echo >/dev/tcp/127.0.0.1/9099) >/dev/null 2>&1; then
    AUTH_READY=true
    break
  fi
  sleep 2
  AUTH_WAITED=$((AUTH_WAITED + 2))
  printf "  Waiting for Auth... (%d/%d s)\r" "$AUTH_WAITED" "$MAX_WAIT"
done
echo ""
if [ "$AUTH_READY" != true ]; then
  fail "Auth emulator (9099) did not accept connections. Demo users cannot be seeded. See docs/INSTALL.md (emulator ports)."
fi
ok "Auth emulator is ready."
echo "  (Brief settle before seed...)"
sleep 5

# ─── Step 6: Seed demo data ───────────────────────────────────
step "Seeding demo users and data..."
cd "$REPO_ROOT/functions"
node scripts/seed-local.js || fail "Seed script failed. After emulators are healthy, run: cd functions && npm run seed:local"
cd "$REPO_ROOT"
ok "Seed complete.  Login: student@example.com / Passw0rd!"

# ─── Step 7: Detect Flutter target and launch ────────────────
step "Detecting Flutter run target..."
# Prefer Chrome; fall back to first available device
TARGET=""
DEVICES_JSON=$(flutter devices --machine 2>/dev/null || echo "[]")
CHROME_ID=$(echo "$DEVICES_JSON" | python3 -c "
import sys, json
devs = json.load(sys.stdin)
for d in devs:
    if 'chrome' in (d.get('id','') + d.get('sdk','')).lower():
        print(d['id']); break
" 2>/dev/null || true)

if [ -n "$CHROME_ID" ]; then
  TARGET="$CHROME_ID"
  ok "Selected target: Chrome ($TARGET)"
else
  FIRST_ID=$(echo "$DEVICES_JSON" | python3 -c "
import sys, json
devs = json.load(sys.stdin)
if devs: print(devs[0]['id'])
" 2>/dev/null || true)
  if [ -n "$FIRST_ID" ]; then
    TARGET="$FIRST_ID"
    ok "Selected target: $TARGET"
  else
    warn "No Flutter devices found. Flutter will prompt you."
  fi
fi

step "Launching Flutter app against local emulators..."
FLUTTER_ARGS=(run --dart-define=USE_LOCAL_EMULATORS=true)
[ -n "$TARGET" ] && FLUTTER_ARGS+=(-d "$TARGET")
flutter "${FLUTTER_ARGS[@]}"
