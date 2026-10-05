# Blood450 — Google Sign-In / OAuth Deployment Checklist

Do not commit secrets. Keep `GOOGLE_OAUTH_CLIENT_SECRET` only in server env.

## Flutter (mobile JWT)

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>
```

`GOOGLE_SERVER_CLIENT_ID` must equal Django `GOOGLE_OAUTH_CLIENT_ID` (Web OAuth client).

## Google Cloud Console

1. **Web application** client:
   - Authorized JavaScript origins: `https://<deployed-domain>`
   - Authorized redirect URIs: `https://<deployed-domain>/register/google/callback/`
2. **Android** client (for `google_sign_in`):
   - Package name: `com.example.ayh_mobile` (confirm in `android/app/build.gradle.kts`)
   - SHA-1 / SHA-256 of debug (and release) keystore
3. Optional: set `GOOGLE_OAUTH_ANDROID_CLIENT_ID` in Django `.env` if Android `aud` differs.

## Django env

```
GOOGLE_OAUTH_CLIENT_ID=...
GOOGLE_OAUTH_CLIENT_SECRET=...
GOOGLE_OAUTH_ANDROID_CLIENT_ID=...   # optional
APP_BASE_URL=https://<deployed-domain>
# or
GOOGLE_REDIRECT_URI=https://<deployed-domain>/register/google/callback/
```

## API

`POST /api/auth/google/` body `{ "id_token": "..." }` → JWT access + refresh (same as password login).
