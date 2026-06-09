# Legal & licensing (portfolio use)

> **This is not legal advice.** It is a practical checklist for publishing this repository on GitHub as a **portfolio / educational** project. Consult a qualified lawyer before operating a live product for students or minors.

## Your code

- **License:** [MIT License](../LICENSE) (Copyright © 2026 Antonios Psarras).
- **What MIT allows:** Others may fork, study, modify, and redistribute your code with attribution and the same license notice.
- **What MIT does not do:** It does not grant trademark rights, imply endorsement, or remove your **disclaimer of warranty** (software is provided “AS IS”).

## Third-party software in this repo

| Component | Role | Typical license / terms |
| --- | --- | --- |
| **Flutter / Dart SDK** | App framework | BSD-style (see [flutter.dev](https://flutter.dev)) |
| **Packages in `pubspec.yaml`** | App dependencies | Each package has its own license (mostly BSD/MIT/Apache); see `pubspec.lock` and package sites |
| **Firebase (Auth, Firestore, Functions, Storage, FCM)** | Backend when deployed | [Firebase Terms](https://firebase.google.com/terms) and Google Cloud terms apply to **your** Firebase project |
| **Node.js Cloud Functions** | Server logic | Dependencies in `functions/package.json` (Apache/MIT mix via Google SDKs) |
| **Google Generative AI (`@google/generative-ai`)** | Server-side Gemini | [Google AI / API terms](https://ai.google.dev/terms) — **deployers** must comply; minors and production use have extra restrictions |
| **Tavily** (optional) | Web search for exam quizzes | Tavily API terms if you set `TAVILY_API_KEY` |
| **EmailJS** (optional) | Parental consent / Pro activation emails | EmailJS terms if you configure secrets |
| **google_fonts** package | Downloads fonts at runtime | Fonts are subject to their respective OFL/Apache licenses; attribution is handled by the package when fonts are fetched |

## Assets shipped in the repository

| Asset | Notes |
| --- | --- |
| **`assets/branding/`** | Project branding (your work under MIT) |
| **`assets/avatars/*.svg`** | Simple original vector placeholders (MIT) |
| **`docs/screenshots/`** | UI captures of the app (your work; no third-party stock implied) |
| **`assets/.env.demo` / `functions/.env.demo`** | Placeholder Firebase config for **local emulators only** — not live production keys |

## Trademarks

**Google**, **Firebase**, **Gemini**, **Flutter**, and other names are trademarks of their respective owners. This portfolio project is **not affiliated with or endorsed by Google**.

The name **ScholiLink** is used as a product label in this showcase; if you fork the repo, consider renaming to avoid confusion with any future commercial product.

## What you are *not* granting by open-sourcing

- Permission for anyone to run a **production** student social + AI platform for minors without their own legal review.
- Compliance with **GDPR**, **COPPA**, Greek education privacy law, or **App Store “Kids”** policies — those obligations fall on whoever deploys.
- Rights to use **Google AI** or **Firebase** beyond each provider’s current terms and billing setup.

## Recommended disclaimer (already in README)

Keep the README portfolio notice visible: archived showcase, no maintenance, no liability for deployment, especially for under-18 users. That aligns user expectations with MIT’s warranty disclaimer.

See also: [PRIVACY-NOTICE.md](PRIVACY-NOTICE.md), [PUBLISHING.md](PUBLISHING.md), [README disclaimer](../README.md#why-open-source-the-disclaimer).

## Before you fork or deploy

1. Replace all `YOUR_*` values and demo project ids with **your** Firebase project.
2. Never commit `assets/.env`, `functions/.env`, keystores, or service account JSON.
3. Run `flutter analyze`, `flutter test`, and `npm audit` in `functions/`.
4. If you ship to stores, add your own privacy policy, terms of use, and age/consent flows — this repo’s flows are **demonstration-only**.
