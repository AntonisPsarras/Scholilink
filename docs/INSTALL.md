# Installation & environment setup

This guide is the **full technical path** from a clean machine to a running ScholiLink app: prerequisites, local Firebase emulators, optional live cloud mode, and troubleshooting.

**New here?** Read the [root README](../README.md) for the product story and screenshot gallery. For a **feature-by-feature map** of what exists in `lib/features/`, see [FEATURES.md](FEATURES.md). Ready to contribute? See [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## Table of contents

0. [Feature map (code parity)](FEATURES.md)
1. [Firebase config for forks](#firebase-config-for-forks)
2. [Choose your setup path](#choose-your-setup-path)
3. [Prerequisites](#prerequisites)
4. [Verify your toolchain](#verify-your-toolchain)
5. [Firebase CLI login](#firebase-cli-login)
6. [Local demo (emulators, zero cloud)](#local-demo)
7. [Live cloud (real Firebase + Gemini)](#live-cloud)
8. [Troubleshooting](#troubleshooting)

---

<a id="firebase-config-for-forks"></a>

## Firebase config for forks

This repository **does not** include production Firebase client credentials. The following are listed in **`.gitignore`** and will **not** be present after `git clone`:

| Path | Role |
| --- | --- |
| `lib/firebase_options.dart` (and any `**/firebase_options.dart`) | Optional FlutterFire-generated options — **not required**; runtime init reads **`assets/.env`** via `lib/core/firebase_app_options.dart` |
| `android/app/google-services.json` | Android native plugin config (download from **your** Firebase project) |
| `ios/Runner/GoogleService-Info.plist` | iOS / macOS native plugin config (download from **your** project) |
| `assets/.env` | Your private Flutter env file (copy from `assets/.env.example`) |

**If you fork or clone this repo**, you must wire up **your own** Firebase project for live cloud use:

1. Copy **`assets/.env.example`** → **`assets/.env`** and replace every `YOUR_*` placeholder with values from **your** Firebase console (Project settings → Your apps).
2. Optionally download **`google-services.json`** / **`GoogleService-Info.plist`** for native targets (recommended for Android/iOS; both stay gitignored).
3. Optionally run `flutterfire configure` to generate **`lib/firebase_options.dart`** locally — the app does not depend on that file being committed.

**Committed `*.env.demo` files are emulator-only.** `assets/.env.demo` and `functions/.env.demo` use the local emulator project id **`student-dashboard-greece`** (see **`.firebaserc`**) and placeholder app IDs. They exist only for the [local demo](#local-demo) track (`USE_LOCAL_EMULATORS=true`, `LOCAL_DEMO_MODE=true`). They are **not** shared production credentials and must **not** be your sole config for a real Firebase project, store build, or public deployment.

---

## Choose your setup path

| Track | Best for | What you get |
| --- | --- | --- |
| **Local demo** | Fast onboarding, interviews, contributor smoke tests | Firebase Emulator Suite, seeded users, deterministic AI mocks — no cloud project or API keys |
| **Live cloud** | End-to-end Firebase + real Gemini + email flows | Real project, secrets, deploys, production-like behavior |

---

## Prerequisites

Install the following before running anything. Every item on this list is **required** for the local demo — missing even one will cause failures that can look unrelated.

| Tool | Required version | Download |
| --- | --- | --- |
| **Flutter SDK** | `>= 3.38.4` | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| **Dart SDK** | `>= 3.10.3` | Bundled with Flutter |
| **Node.js** | `22.x` | [nodejs.org](https://nodejs.org/en/download) |
| **Firebase CLI** | Latest | `npm install -g firebase-tools` |
| **Java JDK** | **`21+` (required)** | [adoptium.net](https://adoptium.net/) |
| **Git** | Any | [git-scm.com](https://git-scm.com/) |

> **Why Java?** The Firestore emulator is a JVM process. Without Java 21+, the emulator will refuse to start and the entire local demo collapses. This is the single most common setup failure — install it first.

---

## Verify your toolchain

Run these before anything else. Fix any failures before continuing.

```bash
flutter doctor
node -v          # should print v22.x.x
firebase --version
java -version    # should print openjdk 21 or higher
```

---

## Firebase CLI login

```bash
firebase login
```

You only need to do this once per machine. The local emulator does not require a cloud project, but the CLI must be authenticated.

---

<a id="local-demo"></a>

## Local demo (emulators, zero cloud)

This is the fastest path from a fresh clone to a fully running, interactive app — **no cloud deploy, no paid plan, and no secrets in your own `.env` files** (the committed `*.env.demo` templates are enough).

> **Emulator project id:** The Firebase CLI loads **`.firebaserc`** (default **`student-dashboard-greece`**) so the Emulator hub, Cloud Functions URLs, and Auth namespace all match that id. **`assets/.env.demo` uses the same `FIREBASE_PROJECT_ID`**. If the app used a different id (for example a fake `demo-student-dashboard` name), Auth would not find the seeded users even though seeding appeared to succeed — see emulator logs for “Multiple projectIds” warnings.

The automated script:

1. Checks your toolchain (Flutter, Node, Firebase CLI, Java)
2. Installs Flutter and Cloud Functions dependencies
3. **Syncs** the committed demo environment files (`assets/.env.demo` → `assets/.env`, `functions/.env.demo` → `functions/.env`) so the Firebase **project id matches the Auth emulator namespace** used when seeding accounts (see [Troubleshooting — demo login fails](#demo-login-fails-invalid-credentials-or-user-not-found))
4. Boots the Firebase Emulator Suite (Auth, Firestore, Functions, Storage)
5. Waits until the Firestore and Auth emulators accept connections
6. Seeds two demo user accounts and sample data
7. Detects the best available Flutter target (prefers Chrome)
8. Launches the app with `--dart-define=USE_LOCAL_EMULATORS=true`

By default the demo launcher **overwrites** `assets/.env` and `functions/.env` every run. That is intentional: a leftover “live cloud” `.env` is the most common reason demo passwords appear broken. To keep your existing files (only if they already use **`FIREBASE_PROJECT_ID=student-dashboard-greece`** — the same id as the Emulator hub — and local emulator settings), use **`.\Start-Demo.ps1 -KeepExistingEnv`** on Windows or **`bash start-demo.sh --keep-existing-env`** on macOS / Linux / WSL.

### Clone the repository

```bash
git clone https://github.com/AntonisPsarras/Scholilink
cd Scholilink
```

The Flutter app and scripts (`Start-Demo.ps1`, `start-demo.sh`, `pubspec.yaml`) live at the **repository root** — not in a nested subfolder.

### Run the demo script

**macOS / Linux / WSL:**

```bash
chmod +x start-demo.sh
./start-demo.sh
```

To keep existing `assets/.env` / `functions/.env` (advanced — only if already demo-aligned):

```bash
./start-demo.sh --keep-existing-env
```

**Windows (PowerShell):**

```powershell
.\Start-Demo.ps1
```

Preserve existing `assets/.env` / `functions/.env` (advanced — only if already demo-aligned):

```powershell
.\Start-Demo.ps1 -KeepExistingEnv
```

> **Windows users:** If you see `cannot be loaded because running scripts is disabled`, see [PowerShell execution policy](#powershell-execution-policy-blocks-the-script-windows) below.

### Manual local demo (without the launcher script)

Use this when you prefer separate terminals or CI-style steps.

> **Build prerequisite:** `pubspec.yaml` lists `assets/.env` as an explicit asset. Flutter's build tool fails at bundle time (`No file or variants found for asset: assets/.env`) if the file is absent — even if `main.dart` has a runtime fallback. Always run the copy commands below **before** `flutter build apk` or `flutter run`.

```bash
cp assets/.env.demo assets/.env
cp functions/.env.demo functions/.env
cd functions
npm ci
npm run build
npm run emulators
```

In a second terminal, after the emulators are up (Firestore **8080** and Auth **9099** accepting connections):

```bash
cd functions
npm run seed:local
cd ..
flutter pub get
flutter run --dart-define=USE_LOCAL_EMULATORS=true
```

The same demo accounts apply (see below). Never mix `assets/.env` from **live cloud** setup with `USE_LOCAL_EMULATORS=true` unless `FIREBASE_PROJECT_ID` is exactly the project id used by **`firebase emulators:start`** for this repo (by default **`student-dashboard-greece`**, matching `.firebaserc` and `assets/.env.demo`).

### Demo login credentials

These accounts exist **only** in the **local Firebase Auth emulator** after a successful `seed:local` run. They are **not** created in any real Firebase project.

| Account | Email | Password |
| --- | --- | --- |
| Primary student | `student@example.com` | `Passw0rd!` |
| Teammate | `teammate@example.com` | `Passw0rd!` |

Log in with either account to explore the full feature set: homework feed, classroom chat, AI tutor, smart notes, exam readiness, grades, and the social profile system.

**Requirements for a successful login:** (1) Auth emulator running on **9099**, (2) app built with **`USE_LOCAL_EMULATORS=true`** (the demo script passes this automatically), (3) **`FIREBASE_PROJECT_ID` in `assets/.env` must match** the project id the Emulator hub uses when you run `firebase emulators:start` — in this repository that is **`student-dashboard-greece`** (see **`.firebaserc`** and **`firebase.json`**). The committed `assets/.env.demo` matches that id so the seed script and Flutter hit the same Auth namespace.

### What “demo mode” means for AI features

In local demo mode (`LOCAL_DEMO_MODE=true` in `functions/.env`), all AI Cloud Function calls return deterministic, pre-scripted responses instead of hitting the real Gemini API. This means:

- The AI tutor replies with a fixed Greek-language demo message.
- OCR returns a mock homework item.
- The exam quiz generator returns deterministic placeholder questions.

Everything else — auth, Firestore, Storage, messaging, classroom features — runs against real (local) emulators with full functionality.

---

<a id="live-cloud"></a>

## Live cloud (real Firebase + Gemini)

Use this path when you want real Firebase infrastructure, real Gemini AI responses, and real email delivery for the parental consent flow.

### A) Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com/) and create a new project.
2. Enable the following services:
   - **Authentication** (enable Email/Password and Google providers)
   - **Firestore Database** (start in production mode)
   - **Cloud Functions** (requires Blaze/pay-as-you-go plan)
   - **Cloud Storage**
3. Connect the CLI to your project:

```bash
firebase login
firebase use --add   # select your new project
```

### B) Register client apps in Firebase

Go to **Project Settings → Your apps** and register:

- A **Web** app
- An **Android** app (if targeting Android)
- An **iOS** app (if targeting iOS / macOS)

Copy the resulting configuration values. You will need them in the next step.

### C) Configure `assets/.env`

Copy the example file and fill in your values:

```bash
cp assets/.env.example assets/.env
```

Open `assets/.env` and fill in every `YOUR_*` placeholder with the real values from your Firebase project settings:

```env
USE_LOCAL_EMULATORS=false

FIREBASE_PROJECT_ID=your-real-project-id
FIREBASE_MESSAGING_SENDER_ID=your-sender-id
FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com

FIREBASE_WEB_API_KEY=your-web-api-key
FIREBASE_WEB_APP_ID=1:000000000000:web:your-web-app-id

FIREBASE_ANDROID_API_KEY=your-android-api-key
FIREBASE_ANDROID_APP_ID=1:000000000000:android:your-android-app-id

FIREBASE_IOS_API_KEY=your-ios-api-key
FIREBASE_IOS_APP_ID=1:000000000000:ios:your-ios-app-id
FIREBASE_IOS_BUNDLE_ID=com.example.student_dashboard

GOOGLE_CLIENT_ID=your-oauth-client-id.apps.googleusercontent.com
```

### D) Add native config files (optional but recommended)

Even though runtime init uses **`assets/.env`** (not a committed `firebase_options.dart`), native Firebase plugins expect platform-specific config from **your** project:

- **Android:** Download `google-services.json` from Firebase Console → place at `android/app/google-services.json`
- **iOS:** Download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`

These paths, `lib/firebase_options.dart`, and `assets/.env` are **gitignored** — fork each maintainer’s own copies; never commit them. See [Firebase config for forks](#firebase-config-for-forks).

### E) Configure Cloud Functions environment

Install dependencies:

```bash
cd functions
npm ci
cd ..
```

> **⚠️ Moderation note:** `GOOGLE_AI_API_KEY` powers both AI features **and** server-side chat moderation (`moderateStudentMessage` callable plus Firestore `onCreate` triggers on classroom/DM messages). Outside `LOCAL_DEMO_MODE`, if this key is absent, moderation **fails closed** — unchecked text messages are rejected or removed. Always set a valid key in live-cloud deployments.

Create `functions/.env` with your Gemini API key:

```bash
cp functions/.env.example functions/.env
```

```env
GOOGLE_AI_API_KEY=your-real-gemini-api-key
GEMINI_MODEL=gemini-2.5-flash
LOCAL_DEMO_MODE=false

# Optional: enables web-augmented exam quiz generation
TAVILY_API_KEY=your-tavily-api-key
```

Get a Gemini API key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey). Enable the **Generative Language API** on your GCP project.

### F) Set production secrets (EmailJS parental consent)

The parental consent email flow uses Firebase Secret Manager. Set these once:

```bash
firebase functions:secrets:set PARENT_CONSENT_EMAILJS_SERVICE_ID
firebase functions:secrets:set PARENT_CONSENT_EMAILJS_TEMPLATE_ID
firebase functions:secrets:set PARENT_CONSENT_EMAILJS_PUBLIC_KEY
firebase functions:secrets:set PARENT_CONSENT_EMAILJS_PRIVATE_KEY
```

Paste the values from your [EmailJS dashboard](https://www.emailjs.com/) when prompted. These secrets are automatically wired into the deployed functions on every `firebase deploy`.

### G) Deploy Cloud Functions

```bash
cd functions
npm run build
cd ..
firebase deploy --only functions
```

### H) Deploy Firestore rules, Storage rules, and indexes

```bash
firebase deploy --only firestore,storage
```

### I) Run Flutter in cloud mode

```bash
flutter pub get
flutter run --dart-define=USE_LOCAL_EMULATORS=false
```

Omitting the `--dart-define` flag also defaults to cloud mode.

---

## Android release APK (sideload / test on device)

```bash
cp assets/.env.example assets/.env   # fill FIREBASE_ANDROID_* for gr.scholilink.app
flutter build apk
# output: build/app/outputs/flutter-apk/app-release.apk
```

**Package name:** `gr.scholilink.app` (not `com.example.*`). Play Protect often flags sideloaded `com.example` builds as suspicious.

**Signing:** Release builds use `android/upload-keystore.jks` + `android/key.properties` (both gitignored). Generate once with:

```powershell
.\tools\generate_android_keystore.ps1
```

Register the keystore SHA-1 in Firebase → Project settings → **ScholiLink** Android app. **Keep the keystore safe** — every future APK must be signed with the same file or Android will refuse to upgrade in place.

**Smaller APKs:** `flutter build apk --split-per-abi` (install the `arm64-v8a` build on most phones).

**First install after this migration:** Uninstall any old `com.example.student_dashboard` build once. Later updates with the same keystore install normally without uninstalling.

**Harmless build log noise:** `kotlin.Metadata` version notes, Java deprecation notes, and “packages have newer versions” are warnings only — the APK still builds.

---

## Troubleshooting

Something broke. Don't panic — it's almost certainly one of the things below.

### Android: must uninstall old APK / Play Protect warning

**Symptom:** Installing the new APK fails unless you delete the old app, or Google Play Protect says the app is harmful or violates Play policy.

**Causes fixed in this repo:**

1. **`com.example.student_dashboard`** — default Flutter ID; Play Protect treats many sideloaded `com.example` apps as untrusted.
2. **Debug-signed release APKs** — rebuilding on another PC or mixing `flutter run` with `flutter build apk` used different debug keys, so Android treated each build as a different app.

**Fix:** Use the current `gr.scholilink.app` release build signed with your persistent `upload-keystore.jks`. Update `assets/.env`:

```env
FIREBASE_ANDROID_APP_ID=1:158790888866:android:00ca9085c021735ad656fb
```

Uninstall the legacy app once, then install `app-release.apk`. Future builds with the same keystore upgrade in place.

### Demo login fails (invalid credentials or user not found)

**Symptom:** `student@example.com` / `Passw0rd!` (or the teammate account) never succeeds, often with “wrong password” or “user not found,” even though the seed step reported success.

**Root cause (most common):** The Firebase **Auth emulator isolates users per `FIREBASE_PROJECT_ID`**. The seed script and the Flutter app must use the **same** id as the Emulator hub (see `firebase emulators` output: Functions URLs use `http://127.0.0.1:5001/<projectId>/...`). This repo uses **`student-dashboard-greece`** in **`.firebaserc`**, **`assets/.env.demo`**, and the seed fallback. If `assets/.env` uses a **different** id (for example an old **`demo-student-dashboard`** copy, or another Firebase project), the app signs in under one Auth namespace while demo users were created under another — logins fail even with the correct password.

**Fix:**

1. Copy the demo templates again: `cp assets/.env.demo assets/.env` (and `functions/.env.demo` → `functions/.env` if needed).
2. Confirm **`.firebaserc`** default project is **`student-dashboard-greece`** (or run `firebase use student-dashboard-greece` before starting emulators).
3. Stop emulators, restart them, and re-run **`npm run seed:local`** from `functions/`.
4. Restart Flutter with **`flutter run --dart-define=USE_LOCAL_EMULATORS=true`** (hot reload does not re-read `.env`).

Or re-run **`.\Start-Demo.ps1`** / **`./start-demo.sh`** without `-KeepExistingEnv` so the script refreshes the demo `.env` files automatically.

**Other causes:** Auth emulator not running yet when seed ran (re-run `npm run seed:local`), or you are hitting **production** Firebase (`USE_LOCAL_EMULATORS` false) where these emails were never registered.

### Seed fails with `ECONNREFUSED 127.0.0.1:9099` (Auth emulator)

**Symptom:** The seed step throws `connect ECONNREFUSED` on port **9099**, or the updated `Start-Demo.ps1` exits saying Auth never became ready.

**Cause:** The Firebase **Auth** emulator often starts **after** the Firestore JVM is already accepting traffic on **8080**. Running the seed too early talks to Auth before it is listening.

**Fix:** Use the latest `Start-Demo.ps1` / `start-demo.sh` from this repo (they wait for **both** 8080 and 9099, then pause briefly before seeding). If you start emulators manually, wait until the emulator terminal shows **all** services up, then run `cd functions && npm run seed:local`.

### PowerShell: execution policy blocks the script (Windows)

**Symptom:** Running `.\Start-Demo.ps1` immediately gives:

```
cannot be loaded because running scripts is disabled on this system
```

**Fix:** Temporarily relax the execution policy for your current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Start-Demo.ps1
```

Alternatively:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Demo.ps1
```

### Permission denied on `start-demo.sh` (macOS / Linux)

**Symptom:** `bash: ./start-demo.sh: Permission denied`

**Fix:**

```bash
chmod +x start-demo.sh
./start-demo.sh
```

### Java errors / Firestore emulator won't start

**Symptom:** The emulator window opens and then immediately closes, or you see errors like `Error: Could not find or load main class` or `JAVA_HOME is not set`.

**Root cause:** Either Java is not installed, the wrong version is active, or `JAVA_HOME` is not pointing at the JDK.

**Fix:**

1. Confirm Java 21+ is active:

```bash
java -version
# Expected: openjdk version "21.x.x" or higher
```

2. If the version is wrong, install the correct JDK from [adoptium.net](https://adoptium.net/) and make sure it is first on your `PATH`.

3. On Windows, also set `JAVA_HOME`:

```text
JAVA_HOME = C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot
```

4. On macOS with multiple JDKs via Homebrew:

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

### Emulator ports are already in use

**Symptom:** The emulator fails to bind to one of its ports (8080, 9099, 5001, 9199). You may see `address already in use`.

| Emulator | Port |
| --- | --- |
| Firestore | `8080` |
| Auth | `9099` |
| Functions | `5001` |
| Storage | `9199` |

**Fix (macOS / Linux):**

```bash
# Replace 8080 with whichever port is blocked
lsof -ti :8080 | xargs kill -9
```

**Fix (Windows):**

```powershell
netstat -ano | findstr :8080
taskkill /PID 12345 /F
```

**Alternative:** Change the emulator ports in `firebase.json` under the `"emulators"` key, then update the corresponding `FIREBASE_*_EMULATOR_PORT` values in `assets/.env`.

### App boots but every Firebase call fails instantly

**Symptom:** The app loads but immediately shows errors, the login button does nothing, or the AI features return "not configured."

**Most likely cause:** `assets/.env` is missing, was not copied correctly, or still contains `YOUR_*` placeholder values.

**Fix:**

1. Confirm the file exists: `ls assets/.env` (or check in your file explorer on Windows).
2. Open it and verify the `FIREBASE_PROJECT_ID` and API key fields are not placeholders.
3. For the demo track, make sure `USE_LOCAL_EMULATORS=true` is set — the demo values only work against the local emulator, not against a real Firebase project.
4. Re-run Flutter after any `.env` change (hot reload does not re-read `.env`):

```bash
flutter run --dart-define=USE_LOCAL_EMULATORS=true
```

### Seed script fails or returns "connection refused"

**Symptom:** `npm run seed:local` (or the automated step inside the demo script) throws a connection error.

**Root cause:** The seed script ran before the Firestore emulator finished starting.

**Fix:** Wait 10–15 seconds after the emulator window opens, then run the seed manually:

```bash
cd functions
npm run seed:local
cd ..
```

### AI features return "not configured" or "API key" errors (cloud mode only)

**Symptom:** The AI tutor, smart notes, or exam quiz features show an error mentioning `GOOGLE_AI_API_KEY` or "AI service is not configured."

**Fix checklist:**

1. Open `functions/.env` and confirm `GOOGLE_AI_API_KEY` contains a real key (not `demo-gemini-api-key` or `YOUR_*`).
2. Confirm `LOCAL_DEMO_MODE=false`.
3. Confirm the **Generative Language API** is enabled in your Google Cloud Console for the project linked to your API key.
4. Confirm `GEMINI_MODEL=gemini-2.5-flash` (or another model your key has access to).
5. Restart the emulator after any `functions/.env` change — the Functions emulator does not hot-reload env vars.

### `build_runner` errors in the IDE

**Symptom:** Your IDE suggests running `flutter pub run build_runner build`, or you see stale generated file errors.

**Fix:** This project does **not** use `build_runner`. Clear the Flutter cache:

```bash
flutter clean
flutter pub get
```

### `npm run emulators` fails with a TypeScript compile error

**Symptom:** The emulator start command exits with a TypeScript error immediately.

**Fix:**

```bash
cd functions
npm ci
npm run build
cd ..
```

If `npm run build` reports TypeScript errors, fix them before re-running the emulators.

---

## License / usage note

Portfolio showcase repository for technical evaluation, architecture review, and interview discussion. Not licensed for production deployment as a minor-facing application without independent legal and compliance review. Details: [README — disclaimer](../README.md#why-open-source-the-disclaimer).
