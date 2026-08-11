# Blood Bank Management System – Architecture

This document describes how the **Android (Flutter)** app and the **website** work with the backend.

---

## High-level architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Flutter app (APK / Play Store)  ──────►  Django REST API (Vercel)      │
│                                                    │                     │
│                                                    ▼                     │
│                                            Supabase (PostgreSQL)         │
│                                            = database only               │
├─────────────────────────────────────────────────────────────────────────┤
│  Website (Django on Vercel)  ──────────────────────►  same Supabase DB   │
└─────────────────────────────────────────────────────────────────────────┘
```

- **Flutter app:** One APK. Always calls the **Django API** hosted on Vercel (`https://blood-450-gqkc.vercel.app/api/`). No direct Supabase connection from the app.
- **Django (Vercel):** Serves the website and the REST API. Uses **Supabase** as its database via `DATABASE_URL`.
- **Supabase:** Database only (PostgreSQL). No Supabase Auth or client SDK in the Flutter app.

---

## Configuration

### Flutter app

- **API base URL** is set in `lib/core/constants/api_constants.dart`:
  - `baseUrl = 'https://blood-450-gqkc.vercel.app/api/'`
- Change this constant if your Vercel project URL is different.
- No `--dart-define`, env files, or backend switching. One build works everywhere.

### Django (Vercel)

- Set **Vercel environment variables** for the Django project (see `AYH/DEPLOY_VERCEL.md`), including:
  - `DATABASE_URL` – Supabase PostgreSQL connection string (use pooling URI from Supabase dashboard).
  - Other keys (e.g. `SECRET_KEY`, `APP_BASE_URL`, Google OAuth if used).

---

## Build commands

### Run locally

```bash
# From ayh_mobile/
flutter run
```

The app will call the **Vercel** API. No local Django needed unless you want to test against a local server (in that case, temporarily change `baseUrl` in `api_constants.dart` to your local URL, e.g. `http://10.0.2.2:8000/api/` for Android emulator).

### Build APK or App Bundle (Play Store)

```bash
# From ayh_mobile/
flutter build apk
# or
flutter build appbundle
```

No extra flags. The APK/AAB uses the Vercel Django API; Supabase is only used by Django on the server.

---

## Database (Supabase)

Supabase is the **database** for the Django project. Django connects via `DATABASE_URL`. Tables and schema are managed by Django (migrations). You do not need to create Supabase tables by hand for the app; Django’s models and migrations define the schema.

---

## File layout (relevant parts)

```
ayh_mobile/
├── lib/
│   ├── core/
│   │   └── constants/
│   │       └── api_constants.dart   # baseUrl = Vercel Django API
│   ├── data/
│   │   ├── services/                # Django API clients only
│   │   │   ├── auth_service.dart
│   │   │   ├── donor_service.dart
│   │   │   └── ...
│   │   └── repositories/           # All use Django services
│   └── main.dart
└── ARCHITECTURE.md
```

---

## Quick reference

| Goal                    | Action |
|-------------------------|--------|
| Run app                 | `flutter run` |
| Build APK               | `flutter build apk` |
| Build for Play Store    | `flutter build appbundle` |
| Change API URL          | Edit `baseUrl` in `lib/core/constants/api_constants.dart` |
| Database / backend config | Configure Django on Vercel (env vars); Supabase = DB only |
