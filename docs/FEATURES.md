# ScholiLink — product feature map

This document mirrors what is implemented under [`lib/features/`](../lib/features/) so contributors and reviewers can align the **codebase** with **marketing copy** without spelunking every route.

**Related:** [README.md](../README.md) (pitch, gallery, stack), [INSTALL.md](INSTALL.md) (run locally or in the cloud).

---

## Auth and account lifecycle

| Area | What ships today |
| --- | --- |
| **Sign-in** | Email and password, Google Sign-In, remember-me, password reset flow. |
| **Registration** | Account creation path paired with the auth stack. |
| **Onboarding** | First-run profile capture and setup (`user_onboarding_screen`). |
| **Parental consent** | Dedicated consent surface for the minor-facing workflow narrative (`parental_consent_screen`). |
| **Session shell** | `AuthWrapper` routes authenticated users into the main app scaffold. |

---

## Home, dashboard, and shell

| Area | What ships today |
| --- | --- |
| **Dashboard** | Personalized greeting, Sparks balance, calendar with exam vs deadline legend, tomorrow’s task checklist, subject chips, and quick navigation. |
| **Navigation** | Floating “island” bottom navigation, optional **desktop sidebar** and **social sidebar** layouts for wide screens. |
| **Performance** | `PerformanceConfig` bootstraps capability-aware behavior before widgets build. |

---

## Schedule and time

| Area | What ships today |
| --- | --- |
| **Weekly timetable** | Day selector, per-period cards, “next class” banner, and schedule editing (`schedule_editor_screen`). |
| **Deadline tracker** | Capture deadlines and optional presentation flags; integrates with **Google Calendar** helpers where configured. |

---

## Homework workflow

| Area | What ships today |
| --- | --- |
| **Homework feed** | Create, edit, delete, and group assignments by due date with multimedia attachments (including voice and photos). |
| **OCR helpers** | Controllers for homework and term-grade OCR hook into Cloud Functions for structured extraction. |
| **History** | Year-scoped homework history with completion analytics (`homework_history_screen`). |

---

## Grades, exams, and analytics

| Area | What ships today |
| --- | --- |
| **Exam tracker** | Log tests and exams on the Greek 0–20 scale, browse historical performance, and remove entries. |
| **Add grades / drill-down** | Bulk or focused grade entry plus per-subject detail views. |
| **Charts** | In-dashboard progress visualizations (for example `fl_chart` trend lines on the home stack). |
| **Moria calculator** | Orientation-aware **Greek university points (“Μόρια”)** sandbox calculator for planning scenarios. |

---

## Exam readiness (AI-assisted quizzes)

| Area | What ships today |
| --- | --- |
| **Quiz setup** | Configure an AI-generated practice quiz via Cloud Functions. |
| **Quiz taking & results** | Full attempt flow with scoring and review surfaces (`quiz_taking_screen`, `quiz_results_screen`). |

---

## AI surfaces (client UX, server-side intelligence)

| Area | What ships today |
| --- | --- |
| **AI Study Assistant** | Chat-style tutoring with attachment support, spark/credit indicators, and history (`study_buddy_screen`). |
| **Smart Notes** | Markdown-friendly note workspace with AI augmentation (`smart_notes_screen`). |
| **AI settings** | Per-user preferences for AI behavior (`ai_settings_screen`). |
| **Sparks economy** | Shared widgets and messaging for quota / limit UX (`spark_counter_widget`, `spark_limit_message`). |

All generative calls are designed to flow through **Firebase Cloud Functions** in production; local demo mode uses deterministic mocks (see [INSTALL.md](INSTALL.md)).

---

## Classroom, friends, and messaging

| Area | What ships today |
| --- | --- |
| **Classes hub** | Create or join classrooms, manage roster-style metadata (`classroom_screen`, `create_join_dialog`). |
| **Friends** | Friend graph management (`friends_screen`, `friends_view`, `add_friend_dialog`). |
| **Group chat** | Classroom threads with rich composer, polls (`create_poll_dialog`), and voice notes (`voice_recorder_widget`). |
| **Direct messages** | One-to-one chat (`direct_chat_screen`). |
| **Classroom settings** | Administrative toggles for group spaces (`classroom_settings_screen`). |

---

## Profile, settings, and monetization hooks

| Area | What ships today |
| --- | --- |
| **Profile** | Avatar, Sparks, academic band, lessons / absences / tutoring counters, and edit flows (`profile_screen`, `edit_profile_screen`). |
| **Subject management** | Curate the subject list tied to homework and grade surfaces (`manage_subjects_screen`). |
| **Tutoring tracker** | Private-lesson bookkeeping (`manage_tutoring_screen`). |
| **Settings** | Theme, locale, notification, and app preferences (`settings_screen`). |
| **Upgrade / Pro** | In-app surface for premium positioning (`upgrade_pro_screen`). |

---

## Notifications, links, and platform services

| Area | What ships today |
| --- | --- |
| **Push notifications** | Firebase Cloud Messaging background handler in [`main.dart`](../lib/main.dart) plus `push_notification_service`. |
| **Deep links** | `app_links` integration for resume flows (for example parental consent URLs). |
| **Device calendar** | Helpers under `dashboard/services/device_calendar_service.dart` when the host OS exposes calendar APIs. |
| **Local notifications** | Scheduled reminders via `flutter_local_notifications` and `timezone`. |
| **Locale** | `AppLocalizations` with Greek and English support (`shared/app_locale.dart`). |
| **Theming** | Light / dark / system preference via Riverpod (`theme_providers.dart`). |

---

## Keeping this file honest

When you add a new top-level feature directory or primary screen, update this map in the same pull request. That keeps README screenshots, this document, and `lib/features/` aligned for launch reviews.
