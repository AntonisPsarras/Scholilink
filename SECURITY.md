# Security policy

ScholiLink is an **archived portfolio repository**. It is not operated as a production service, and security fixes are provided only on a best-effort basis when the author chooses to update the showcase.

## Supported versions

| Version | Supported |
| --- | --- |
| `main` branch (latest showcase snapshot) | Best-effort only |
| Older tags / forks | Not supported by the author |

## Reporting a vulnerability

If you discover a security issue in this codebase:

1. **Do not** open a public GitHub issue with exploit details.
2. Contact the copyright holder named in [LICENSE](LICENSE) through a **private** channel (for example, GitHub private vulnerability reporting if enabled on the repository, or direct email if you already have the maintainer’s contact from a portfolio site).
3. Include steps to reproduce, affected files, and impact (client-only vs Firebase rules vs Cloud Functions).

Please allow reasonable time for triage. There is no SLA, bug bounty, or paid support.

## Scope notes for reviewers

- **Secrets:** Real API keys, `google-services.json`, `GoogleService-Info.plist`, and `assets/.env` must never be committed. Templates live in `assets/.env.example` and `assets/.env.demo`.
- **AI keys:** Gemini and optional Tavily keys belong in `functions/.env` or Firebase Secret Manager — not in the Flutter client.
- **Demo credentials:** `student@example.com` / `Passw0rd!` exist only in the **local Auth emulator** after seeding; they are not production accounts.
- **Emulators:** `firebase.json` binds Auth, Firestore, Functions, Storage, and the Emulator hub to **`127.0.0.1`** only. Do not run emulators on `0.0.0.0` or expose ports to the public internet.
- **Live cloud:** Deployers are responsible for Firebase rules review, Secret Manager configuration, and compliance (GDPR, minors, AI provider terms). See [README — disclaimer](README.md#why-open-source-the-disclaimer) and [docs/LEGAL.md](docs/LEGAL.md).

## Dependency advisories

Transitive npm advisories under `firebase-admin` may remain until upstream Google SDKs publish compatible fixes. Run `npm audit` in `functions/` before any live deploy and accept only risks you understand.
