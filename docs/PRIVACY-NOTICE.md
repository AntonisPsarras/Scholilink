# Privacy notice (portfolio repository)

> **This is not legal advice.** It describes what data this codebase **can** process when someone deploys it, and what the **local demo** does out of the box.

## Portfolio demo (Firebase emulators)

The one-command demo (`Start-Demo.ps1` / `start-demo.sh`) runs Firebase **locally**. No data leaves your machine unless you configure live cloud keys. Seeded demo accounts (`student@example.com`) exist only in the Auth emulator.

## If you deploy to Firebase (fork authors)

### Categories of data

| Category | Examples | Storage / transit |
| --- | --- | --- |
| Account | Email, password hash, Google profile | Firebase Auth |
| Profile | Name, grade band, avatar, bio | Firestore `users/`, `user_public/` |
| Academic | Grades, homework, exams, schedules | Firestore (user-scoped and class-scoped) |
| Social | Friends, classrooms, chat messages, polls | Firestore + Firebase Storage (scoped media paths) |
| AI | Chat prompts, OCR images, quiz content | Cloud Functions → Google Gemini (server-side) |
| Device | FCM tokens, timezone | Firestore |
| Optional | Parent email, consent tokens | Firestore (server-controlled fields) |

### Third-party processors

Deployers must comply with terms for **Firebase/Google Cloud**, **Google Gemini**, and any optional integrations (**Tavily**, **EmailJS**, **Google Calendar**).

### Security controls in this codebase

- Firestore rules block client writes to consent, billing, moderation, and grade-band fields.
- Classroom join and grade changes go through authenticated Cloud Functions.
- Chat moderation runs server-side (Firestore triggers + callable); production mode fails closed without an AI key.
- Storage rules scope chat/classroom media to members or conversation participants.

### Data deletion

Account deletion calls `deleteOwnUserFirestoreData`, which removes the user Firestore subtree, public profile, peer friend links, direct messages sent by the user, classroom memberships, and uid-scoped Storage files. Cross-user chat history may retain messages from other participants; deployers operating under GDPR should extend erasure policies as needed.

### Minors and parental consent

The app includes a **demonstration** parental-consent flow for AI features (under-15 gate). It is not a certified compliance mechanism. Do not operate for minors without qualified legal counsel.

## In-app privacy policy

This repository does **not** ship an end-user privacy policy or terms of service. Fork authors must add their own before any production deployment.

See also: [LEGAL.md](LEGAL.md), [SECURITY.md](../SECURITY.md), [README disclaimer](../README.md#why-open-source-the-disclaimer).
