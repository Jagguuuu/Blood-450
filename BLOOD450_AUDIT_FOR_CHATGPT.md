# Blood450 — Condensed Project Audit

**Stack:** Django 5.2 + DRF (backend `AYH/`) · Flutter + Provider + Dio (mobile `ayh_mobile/`)  
**Purpose:** Blood donation matching — admins create requests; donors get notified and accept/reject; WhatsApp chat supported.  
**Note:** Read-only audit. Build failures so far are environment (JAVA_HOME / Gradle cache locks), not missing app source.

---

## 1. Workspace

| Folder | Role |
|--------|------|
| `AYH/` | Django backend, REST `/api/`, web admin UI, WhatsApp, Celery, Channels |
| `ayh_mobile/` | Flutter mobile client consuming `/api/` with JWT |

No shared code package — only API contract. Single custom Django app: **`careapp`**.

**Key files:** `AYH/requirements.txt`, `AYH/.env.example`, `AYH/AYH/settings.py`, `careapp/models.py`, `careapp/api_urls.py`, `ayh_mobile/pubspec.yaml`, `ayh_mobile/lib/core/constants/api_constants.dart`, Android Gradle (AGP 8.11.1, Gradle 8.13, Java 17).

---

## 2. Backend (`careapp`)

**Auth:** JWT (SimpleJWT) for mobile · Session for web · OTP + Google OAuth for web register · WS JWT via `?token=`

**Core models (Flutter-facing):** `User`, `DonorProfile` (O2O User), `BloodRequest`, `Notification`, `DonorResponse`

**Also:** `RequestDonorPoolAssignment` (active 5 / standby 10), WhatsApp conversation/message/log, plus many analytics/ops models (`EtaTracking`, `DelayReason`, `BloodBankMaster`, `HospitalMaster`, `DimCity`, etc.) — mostly web/admin, not mobile.

**No M2M.** Business rules: blood compatibility matrix · Haversine radius (~10 km) · first accept wins · optional WhatsApp alerts.

**Services:** `donor_pool_service`, `otp_service`, `whatsapp_*`, Celery tasks, Excel analytics.

**Caveats:** `post_migrate` may reset `admin`/`admin` · JWT blacklist setting on but `token_blacklist` app may be missing · LocMem OTP cache not multi-worker safe.

---

## 3. REST API (prefix `/api/`)

| Method | Endpoint | Auth | Flutter uses? |
|--------|----------|------|---------------|
| POST | `auth/login/` | No | Yes — Login |
| POST | `auth/register/` | No | Yes — Register |
| POST | `auth/logout/` | Yes | Yes |
| GET | `auth/me/` | Yes | Yes — session restore |
| POST | `auth/token/refresh/` | Refresh | Yes — Dio interceptor |
| GET/POST/PATCH… | `donors/`, `donors/me/`, `donors/update_me/` | Yes/Admin list | Yes |
| GET/POST… | `blood-requests/`, `{id}/`, `active/`, `my_requests/` | Yes / Admin create | Partial (create + detail) |
| GET/POST | `notifications/`, mark_read | Yes | List yes; mark_read unused |
| POST | `respond/` body `{blood_request_id, response}` | Yes | Yes |
| GET | `dashboard/` | Admin | Yes |
| GET | `requests/<id>/donor-pools/` | Yes | **No** |
| * | `whatsapp/*` (unread, conversations, messages, send, webhook, admin logs) | Mixed | Chat subset yes |
| WS | `/ws/whatsapp/donor/?token=` | JWT | Yes — Support chat |

Default mobile base URL: Android emu `http://10.0.2.2:8000/api/` · else `http://127.0.0.1:8000/api/` · override `--dart-define=API_HOST=...`

---

## 4. Flutter architecture

```
screens → providers (ChangeNotifier) → repositories → services → ApiClient (Dio)
```

**State:** Provider only · **Nav:** imperative Navigator (`go_router` unused) · **Storage:** secure JWT + SharedPreferences · **Theme:** Material 3 red · **i18n:** none

**Live screens:** Splash → Onboarding → Login/Register → AdminDashboard / CreateRequest · DonorHome / CreateProfile / Profile / Notifications / MyResponses / SupportChat

**Orphan screens:** Landing, Intro, DonorResponseForm  
**Unused deps:** go_router, flutter_svg, cached_network_image, json_annotation  
**Junk:** `lib/Untitled`, empty `config/` & `supabase/`, unused images, `env_prod.env` (Supabase not wired)

**Models:** User, DonorProfile, BloodRequest, NotificationModel, DashboardStats · WhatsApp uses untyped Maps

---

## 5. Screen → API map

```
Login → POST auth/login/ → JWT → Admin | Donor home
Register → POST auth/register/ → CreateProfile → POST donors/
Donor home → GET notifications/ · PATCH donors/update_me/ · GET whatsapp/unread/
Notifications → POST respond/
Admin dashboard → GET dashboard/ · GET donors/ · GET blood-requests/{id}/
Create request → POST blood-requests/ (server matches donors + notifies)
Support chat → whatsapp conversations/messages/send + WS
```

---

## 6. Build stack (Android)

| Item | Value |
|------|-------|
| Dart | `^3.10.7` (~Flutter 3.38) |
| Java | 17 (JAVA_HOME = JDK **root**, not `\bin`) |
| Kotlin | 2.2.20 |
| AGP | 8.11.1 |
| Gradle | 8.13 |
| compile/target SDK | Flutter default (~36) |
| minSdk | ~24 |
| app id | `com.example.ayh_mobile` (placeholder) |

**Known build blockers:** invalid JAVA_HOME · Gradle `transforms` “Could not move temporary workspace” (Windows file lock / Defender) · need SDK 36 + unlocked `~\.gradle`

---

## 7. Main flows

1. **Cold start:** Splash → Onboarding → GET auth/me → Admin | Donor | Login  
2. **Admin request:** POST blood-requests → match donors → Notifications (+ optional WhatsApp/pools)  
3. **Donor accept:** GET notifications → POST respond accepted → first wins  
4. **Chat:** REST + WebSocket with JWT  

Parallel **web admin** at `/dashboard/` etc. (session auth) — same DB.

---

## 8. Gaps & debt

- Flutter defaults to **local** API; docs may mention Vercel — mismatch  
- Donor-pools API unused by app · many backend models unused by mobile  
- No release signing · example applicationId · dead screens/deps  
- Production: fix secret/admin defaults, CORS, HTTPS base URL  

---

## 9. Priority fixes

1. **P0** Fix JAVA_HOME (JDK root) · kill Java/Gradle · clear `~\.gradle\caches\...\transforms` · Defender exclusion · rebuild  
2. **P0** Run Django on `:8000` so emulator can hit `10.0.2.2`  
3. **P1** Align Flutter/Android toolchain (JDK17, AGP, SDK36)  
4. **P1** Wire production API base URL when deploying  
5. **P2** Remove dead Flutter code/deps · JWT blacklist app if needed · real app id + signing  

---

## 10. One-line summary

Blood450 = Django `careapp` system of record + Flutter JWT client for admin/donor blood-request matching and WhatsApp support; architecture is coherent — unblock Windows Gradle/Java first, then production URL and cleanup.
