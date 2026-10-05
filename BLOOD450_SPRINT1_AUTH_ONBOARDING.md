# Blood450 Sprint 1 — Authentication & Onboarding Readiness

**Mode:** Read-only (no code changes)  
**Goal:** Decide if auth/onboarding is ready for a first APK with real users  
**Verdict:** **Not production-ready.** Core JWT login/register works for local/demo use, but several **Critical/High** issues block a real-user APK release.

---

## Part 1 — User Journey (actual code path)

> Note: Real flow is **not** Register → Login → Profile. After register, JWT is already issued; user goes to Create Profile (or Login screen while still logged in). Session check happens on Onboarding finish, not Splash.

### Step map

| Step | Flutter screen | Provider | Repository | Service | API | Django view | Serializer | Model |
|------|----------------|----------|------------|---------|-----|-------------|------------|-------|
| Open app | `SplashScreen` | — | — | — | — | — | — | — |
| Splash → stories | `OnboardingScreen` | — | — | Storage flags | — | — | — | — |
| Session check | `OnboardingScreen._finish` | `AuthProvider.checkLoginStatus` | `AuthRepository` | `AuthService.getCurrentUser` + secure storage | `GET auth/me/` | `current_user_view` | `UserSerializer`, `DonorProfileSerializer` | `User`, `DonorProfile` |
| Login / Register choice | `LoginScreen` | — | — | — | — | — | — | — |
| Registration | `RegisterScreen` (+ `DonorWillingDialog`) | `AuthProvider.register` | `AuthRepository.register` | `AuthService.register` | `POST auth/register/` | `register_view` | `UserRegistrationSerializer` → `UserSerializer` | `User` (+ optional `DonorProfile` if phone) |
| JWT issued | (same register success) | AuthProvider sets logged in | saves tokens | — | response `access`/`refresh` | SimpleJWT `RefreshToken.for_user` | — | — |
| “Login” (existing users) | `LoginScreen` | `AuthProvider.login` | `AuthRepository.login` | `AuthService.login` | `POST auth/login/` | `login_view` | `UserSerializer`, `DonorProfileSerializer` | `User`, `DonorProfile` |
| Create donor profile | `CreateProfileScreen` | `DonorProvider.createProfile` + `AuthProvider.updateDonorProfile` | `DonorRepository` | `DonorService.createProfile` | `POST donors/` | `DonorProfileViewSet.create` | `DonorProfileCreateSerializer` | `DonorProfile` |
| Home | `DonorHomeScreen` (or `AdminDashboardScreen` if `is_staff`) | various | — | — | — | — | — | — |

### Journey quirks (proven)

1. **Register already logs the user in** (tokens saved). Declining the donor dialog navigates to **`LoginScreen` while tokens remain** — confusing UX, not a second login requirement.
2. **Gender** is collected on Register UI but **never sent** to the API.
3. Login without a donor profile still opens **`DonorHomeScreen`** (no forced Create Profile gate).
4. Splash does **no** API; session restore only after onboarding Skip/Get Started.

---

## Part 2 — Registration Validation

### Backend (`UserRegistrationSerializer` / `register_view`)

| Topic | Finding |
|-------|---------|
| Required fields | Model/serializer: `username`, `email`, `password`, `password_confirm`. `first_name`/`last_name` optional (blank OK). `phone` optional. |
| Optional | `phone`, names |
| Password | `min_length=8`; must match confirm. **No** complexity rules (no upper/digit/symbol). Django’s default password validators are **not** applied in this serializer (`create_user` only). |
| Username uniqueness | Yes — Django `User.username` unique → 400 on duplicate |
| Email uniqueness | **No** — Django `User.email` is **not** unique by default; duplicates allowed |
| Phone uniqueness | **No** unique constraint on `DonorProfile.phone`; register phone only creates profile if provided (Flutter does not send phone on register) |
| Blood group | Not part of register API |
| Age | **None** |
| Error responses | `400` with serializer field errors map; Flutter flattens first list/string via `_getErrorMessage` |
| Throttle | `@throttle_classes([])` — **no rate limit** on register |

### Flutter (`RegisterScreen`)

| Topic | Finding |
|-------|---------|
| Required UI | username, email, first/last name (all required in form), password ≥8, confirm match |
| Email | Only checks contains `@` (weak) |
| Password strength bar | UI-only; does not block submit |
| Gender | UI state only — **not in API payload** |
| Error handling | SnackBar with `authProvider.error`; Dio 400 field errors parsed reasonably |
| Success | Tokens saved; Willing dialog → CreateProfile or Login |

---

## Part 3 — Login

| Topic | Finding |
|-------|---------|
| JWT generation | `RefreshToken.for_user(user)` on login/register |
| Token lifetimes | Access **1h**, refresh **7d** (`SIMPLE_JWT`) |
| Token storage | `flutter_secure_storage` (`access_token`, `refresh_token`); user/donor JSON in SharedPreferences |
| Session restore | `checkLoginStatus`: if token present → cache user → `GET auth/me/`. If `me` fails, **`_isLoggedIn` may stay true** from token presence alone |
| Logout | `POST auth/logout/` with refresh → try blacklist → always clear local storage |
| Refresh support | Yes — Dio interceptor on 401 → `POST auth/token/refresh/` |
| Refresh bug | `ROTATE_REFRESH_TOKENS=True` + `BLACKLIST_AFTER_ROTATION=True`, but interceptor **only saves new `access`**, not rotated `refresh`. After first refresh, old refresh may be blacklisted → later 401 loops / forced logout |
| Blacklist app | `rest_framework_simplejwt.token_blacklist` **not** in `INSTALLED_APPS` — blacklist may error; logout still returns 200 |
| 401 handling | Login: shows invalid credentials. Authenticated calls: refresh then retry; refresh fail → `deleteAll` tokens (UI may not navigate to Login until next check) |
| Login throttle | Disabled (`throttle_classes([])`) — brute-force friendly |
| Username/email | Backend resolves username or email via `resolve_login_username` |

---

## Part 4 — Donor Profile (post-auth onboarding)

| Topic | Finding |
|-------|---------|
| Required (Flutter) | Phone (non-empty), blood group |
| Optional | Lat/lng, availability (default true) |
| Flutter validation | Phone non-empty only (no format/length); blood group dropdown; lat/lng range if both parse |
| API validation | Phone required non-empty strip; lat [-90,90], lng [-180,180]; blood_group model choices |
| Duplicate profile | `OneToOne` to User — second `POST donors/` → integrity error (often **500/400**); **no** friendly “already exists” handling in ViewSet |
| Missing mandatory for matching | Location optional — user can finish onboarding with **no coords** → poor matching |
| `phone_verified` | Model field exists; **never set** in mobile create API |
| Response shape risk | Create returns **CreateSerializer** fields only (`phone`, `blood_group`, …) — no `id`/`created_at`. Flutter `DonorProfile.fromJson` defaults `id: 0`. Screen then calls `authProvider.updateDonorProfile(donorProvider.profile!)` — usually non-null if 201, but profile object is **incomplete** |
| No gate | App does not force Create Profile before Home for users without profile |

---

## Part 5 — Security

### Public (AllowAny)

- `POST /api/auth/login/`
- `POST /api/auth/register/`
- `POST /api/auth/token/refresh/`
- `GET /api/` (public root)
- WhatsApp webhook (Meta; separate)

### Protected (typical)

- `GET auth/me/`, `POST auth/logout/` → `IsAuthenticated`
- Donor create/update_me/me → `IsAuthenticated`
- Donor list → `IsAdminUser`
- Blood request create → `IsAdminUser`
- Default DRF → `IsAuthenticated`

### Concerns (from code)

| Issue | Severity |
|-------|----------|
| Login screen shows **test credentials** (`john_donor` / `admin`) | Critical for APK |
| `post_migrate` **resets** `admin` password to `admin` | Critical |
| `ALLOWED_HOSTS = ["*"]` | High |
| Login/register **unthrottled** | High |
| `DonorProfileViewSet` update/destroy: any authenticated user can hit `/donors/{id}/` (object-level permissions **missing**) | High |
| Dio **prints** full request/response (tokens/PII in logs) | High |
| API base URL defaults to **localhost/emulator HTTP**; no production HTTPS default | Critical for real users |
| `usesCleartextTraffic=true` | Expected for local; Medium risk if shipped |
| Email not unique; weak passwords allowed | Medium |
| Gender UI unused; no consent/ToS capture on mobile register | Medium / compliance |
| JWT blacklist app missing vs settings flags | Medium |
| Refresh token not persisted after rotation | High (session reliability) |
| Google OAuth secrets in `.env` (web only) — ensure not shipped in APK (Flutter doesn’t embed them) | OK for mobile; protect backend |

---

## Part 6 — Production Readiness Blockers

| Item | Class |
|------|-------|
| No production API host wired (`10.0.2.2` / `127.0.0.1` defaults) | **Critical** |
| Hardcoded demo credentials on Login UI | **Critical** |
| Auto-reset `admin`/`admin` on migrate | **Critical** |
| Refresh rotation without saving new refresh token | **Critical** |
| Incomplete donor create response → weak local profile state | **High** |
| Session restore may treat user logged-in after failed `auth/me` | **High** |
| No rate limiting on login/register | **High** |
| Object-level donor profile IDOR risk on update/destroy | **High** |
| Debug `print` of API traffic including auth | **High** |
| Register decline → Login while already authenticated | **Medium** |
| No forced Create Profile before Home | **Medium** |
| Email not unique; password policy weak | **Medium** |
| Gender collected but discarded | **Low** |
| Location optional (product quality for matching) | **Medium** |
| `applicationId` still `com.example.ayh_mobile`; debug signing | **High** (store/release) |
| JWT blacklist app not installed | **Medium** |

**Bottom line:** Suitable for **internal/demo APK against a known local/staging server** after removing credential banner. **Not** ready to onboard real public users.

---

## Part 7 — Recommendations (ordered, do not implement here)

| Priority | Issue | Files | Recommended fix | Reason | Expected impact |
|----------|-------|-------|-----------------|--------|-----------------|
| P0 | Production API URL missing | `api_constants.dart`, release config | Ship `--dart-define` / flavor with HTTPS API; refuse localhost in release | Users cannot reach backend | App usable outside emulator |
| P0 | Remove test credentials from Login | `login_screen.dart` | Delete credential helper box | Credential leak / unprofessional | Safer APK |
| P0 | Stop resetting admin password | `careapp/signals.py` | Remove or gate behind DEBUG-only env | Production account takeover | Security |
| P0 | Persist rotated refresh token | `api_client.dart` | On refresh 200, save `access` **and** `refresh` if present | Rotation + blacklist breaks sessions | Stable auth |
| P1 | Add `token_blacklist` or disable blacklist flags | `settings.py`, migrations | Install app + migrate, or set `BLACKLIST_AFTER_ROTATION=False` | Settings/code mismatch | Logout/refresh correctness |
| P1 | Harden session restore | `auth_provider.dart` | If `auth/me` fails after refresh clear → set logged out → Login | Stale “logged in” state | Reliable onboarding |
| P1 | Donor create response | `api_views.py` / Flutter | Return `DonorProfileSerializer` on create; or Flutter refetch `donors/me/` | Incomplete profile object | Correct Home state |
| P1 | Rate-limit auth | `api_views.py`, DRF throttles | Enable anon throttle on login/register | Brute force | Security |
| P1 | Object-level donor permissions | `DonorProfileViewSet` | Only owner/admin may update/delete | IDOR | Security |
| P1 | Strip debug API logging in release | `api_client.dart` | Guard `print` with `kDebugMode` | Token/PII leakage | Security |
| P2 | Gate Home on donor profile | Login/Onboarding navigation | If `!hasDonorProfile && !isAdmin` → CreateProfile | Incomplete onboarding | Clearer UX |
| P2 | Fix post-register decline path | `register_screen.dart` | Go to Home or Profile, not Login | Already logged in | Less confusion |
| P2 | Email unique + stronger password | serializers + Flutter | Unique email validator; use Django password validators | Account quality | Data integrity |
| P2 | Phone format / uniqueness policy | model + serializers | Decide E.164 + unique if product needs it | Duplicate donors | Ops quality |
| P2 | Send or remove Gender | Register UI / UserProfile API | Wire to model or remove UI | Dead UI | Honesty |
| P3 | Release applicationId + signing | `build.gradle.kts` | Real package id + keystore | Store readiness | Distribution |
| P3 | Consent / age / ToS | Register | Capture consents if legally required | Compliance | Legal |

---

## Sprint 1 Decision

| Question | Answer |
|----------|--------|
| Is auth/onboarding production-ready for real users? | **No** |
| Can you demo with a closed test group on a controlled server? | **Yes**, after removing login credential banner and pointing API at that server |
| Must-fix before any public APK | P0 items (API URL, credentials UI, admin signal, refresh token save) |

Use this list as the backlog input for the next implementation sprint (auth hardening), separate from Phase 4 runtime E2E testing.
