# Publishing checklist (GitHub portfolio)

Use this checklist before making the repository public or tagging a release snapshot.

## Secrets and credentials

- [x] Confirm `assets/.env`, `functions/.env`, `google-services.json`, and `GoogleService-Info.plist` are **not** tracked (`git ls-files` should return nothing for these paths).
- [x] Run `git log --all -- assets/.env functions/.env android/app/google-services.json` — no historical commits with live keys (empty log = good).
- [x] Replace every `YOUR_*` placeholder in forked Firebase projects; demo values in `assets/.env.demo` are emulator-only (no `YOUR_*` in committed templates).
- [ ] **Manual (GCP Console):** Restrict Firebase / GCP API keys — Android app id, iOS bundle id, web origin allowlists. See [Google Cloud credentials](https://console.cloud.google.com/apis/credentials?project=student-dashboard-greece).

## Static analysis and tests

```bash
flutter pub get && flutter analyze && flutter test
cd functions && npm ci && npm run build && npm audit --audit-level=high
```

- [x] `flutter analyze` — no issues (verified locally).
- [x] `flutter test` — 6/6 passed (verified locally).
- [x] `npm run build` in `functions/` — success (verified locally).
- [ ] `npm audit --audit-level=high` — may report transitive advisories under `firebase-admin`; review before live deploy (see [SECURITY.md](../SECURITY.md)).
- [x] CI workflow matches the commands above (`.github/workflows/ci.yml`).

## Firebase rules and functions

Deploy with **`storage`**, not `storage:rules`. Storage does not support the `:rules` filter — that syntax makes the CLI look for a storage *target* named `rules` and fails.

```bash
firebase deploy --only firestore:rules,storage,functions
```

Alternative (deploy everything in one service group):

```bash
firebase deploy --only firestore,storage,functions
```

- [x] Firestore + Storage rules + Cloud Functions deployed to `student-dashboard-greece` (verified).
- [ ] Set `GOOGLE_AI_API_KEY` in `functions/.env` (local) or Cloud Functions runtime env / Secret Manager (production) for live AI + chat moderation. Moderation **fails closed** outside `LOCAL_DEMO_MODE`.
- [ ] Optional: EmailJS secrets for parental consent / Pro activation emails.

## Emulator exposure (local demo only)

Emulators in `firebase.json` bind to **`127.0.0.1`** only (not `0.0.0.0`). Never port-forward or run emulators on a public VPS.

- [x] Auth, Firestore, Functions, Storage, and Emulator hub listen on localhost.
- [x] Emulator UI disabled (`"ui": {"enabled": false}`).

## Documentation

- [x] README portfolio disclaimer remains visible.
- [x] UI screenshots committed under `docs/screenshots/` (see `MANIFEST.txt`).
- [x] [PRIVACY-NOTICE.md](PRIVACY-NOTICE.md) and [LEGAL.md](LEGAL.md) present for fork authors.

## Legal posture (portfolio vs production)

This repo is an **archived engineering showcase**, not a GDPR/COPPA-compliant product for minors. Publishing on GitHub under MIT + README disclaimers is appropriate; operating a live student social + AI platform requires independent legal review.

## After publish

- [ ] Enable GitHub private vulnerability reporting (optional).
- [ ] Pin the repository description to “Archived portfolio — not for production use”.
- [x] Do **not** expose Firebase emulators to the public internet (localhost binding in `firebase.json`).

## Quick verification commands

```bash
# Secrets not tracked
git ls-files assets/.env functions/.env android/app/google-services.json

# Rules compile before deploy
firebase deploy --only firestore:rules,storage --dry-run

# Live rules (requires firebase login)
firebase deploy --only firestore:rules,storage,functions
```
