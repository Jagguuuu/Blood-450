# Blood450 — Phase 2: Feature Contract & Call Trace

**Status:** Source of Truth for Phase 3–5  
**Mode:** Read-only (proven from active Flutter navigation + Django code)  
**Baseline:** `BLOOD450_AUDIT_FOR_CHATGPT.md` (architecture assumed known)  
**Scope:** ACTIVE mobile features only. Ignore Landing/Intro/DonorResponseFormScreen and admin-only APIs Flutter never calls.

**Entry:** `main.dart` → `SplashScreen`  
**Base URL:** `http://10.0.2.2:8000/api/` (Android emu) · `http://127.0.0.1:8000/api/` (else) · `--dart-define=API_HOST=...`

---

## 1. Active Features

Proven reachable from Splash → Onboarding → Login | Admin | Donor:

| # | Feature | Role | Primary screens |
|---|---------|------|-----------------|
| F1 | Splash (no API) | All | SplashScreen |
| F2 | Session restore | All | OnboardingScreen |
| F3 | Login | All | LoginScreen |
| F4 | Register | Donor | RegisterScreen + DonorWillingDialog |
| F5 | Create donor profile | Donor | CreateProfileScreen |
| F6 | Donor home | Donor | DonorHomeScreen |
| F7 | Availability toggle | Donor | DonorHomeScreen |
| F8 | Notifications list + respond | Donor | DonorNotificationsScreen + DonorResponseSheet |
| F9 | My responses (view) | Donor | DonorMyResponsesScreen |
| F10 | Donor profile + location | Donor | DonorProfileScreen |
| F11 | Support chat | Donor | SupportChatScreen |
| F12 | Logout | All | DonorHome / AdminDashboard |
| F13 | Admin dashboard | Admin | AdminDashboardScreen + AdminRequestDetailSheet |
| F14 | Create blood request | Admin | CreateRequestScreen |
| F15 | Token refresh (infra) | All | ApiClient interceptor |

**Inactive (do not test as live):** LandingScreen, IntroScreen, DonorResponseFormScreen.

---

## 2. End-to-End Call Traces

### F2 — Session restore

```
User opens app / finishes onboarding
→ SplashScreen (no API) → OnboardingScreen
→ AuthProvider.checkLoginStatus()
→ AuthRepository (isLoggedIn + cache + getCurrentUser)
→ AuthService.getCurrentUser()
→ ApiClient.get → GET auth/me/
→ current_user_view → UserSerializer + DonorProfileSerializer
→ User (+ optional DonorProfile)
→ AuthProvider sets user/donorProfile → notifyListeners()
→ Navigate AdminDashboard | DonorHome | Login
```

### F3 — Login

```
Submit credentials on LoginScreen
→ AuthProvider.login()
→ AuthRepository.login → AuthService.login
→ ApiClient.post → POST auth/login/ {username, password}
→ login_view → UserSerializer (+ DonorProfileSerializer)
→ JWT + user JSON → StorageService (secure tokens + prefs)
→ AuthProvider → notifyListeners()
→ AdminDashboardScreen | DonorHomeScreen
```

### F4 — Register

```
Submit RegisterScreen
→ AuthProvider.register()
→ POST auth/register/ {username, email, password, password_confirm, first_name, last_name}
→ register_view → UserRegistrationSerializer → User (+ optional DonorProfile if phone)
→ tokens stored
→ DonorWillingDialog
  → willing → CreateProfileScreen(bloodGroup)
  → declined → LoginScreen
```

### F5 — Create donor profile

```
CreateProfileScreen submit (+ optional geolocator)
→ DonorProvider.createProfile()
→ POST donors/ {phone, blood_group, is_available, last_lat?, last_lng?}
→ DonorProfileViewSet.create → DonorProfileCreateSerializer
→ DonorProfile row for request.user
→ AuthProvider.updateDonorProfile() (local cache)
→ DonorHomeScreen
```

### F6 / F7 — Donor home + availability

```
DonorHomeScreen init
→ NotificationProvider.loadNotifications() → GET notifications/
→ WhatsAppChatProvider.loadUnread() → GET whatsapp/unread/
→ UI: alerts, badge, chart, nav

Toggle availability
→ DonorProvider.updateProfile() → PATCH donors/update_me/ {is_available}
→ DonorProfileViewSet.update_me → DonorProfileSerializer
→ AuthProvider.updateDonorProfile() → UI refresh
```

### F8 — Notifications + respond

```
Open DonorNotificationsScreen (or sheet from home)
→ GET notifications/ (if reload)
→ DonorResponseSheet Accept/Decline
→ NotificationProvider.respondToRequest()
→ POST respond/ {blood_request_id, response: accepted|rejected}
→ respond_to_request
→ DonorResponse + AdminNotification(on accept) + pool handler + mark Notification read
→ reload notifications → UI status update
```

### F9 — My responses

```
DonorMyResponsesScreen
→ Filters NotificationProvider.notifications where hasResponded (in-memory)
→ Optional sheet → loadNotifications() only
→ Does NOT call POST respond/ on this screen
```

### F10 — Profile location

```
DonorProfileScreen update location
→ DonorProvider.updateMyLocation()
→ PATCH donors/update_me/ {last_lat, last_lng}
→ AuthProvider.updateDonorProfile() → UI
```

### F11 — Support chat

```
SupportChatScreen
→ WhatsAppChatProvider.initChat()
→ WS ws://<host>/ws/whatsapp/donor/?token=<access>
→ GET whatsapp/conversations/
→ GET whatsapp/conversations/{id}/messages/
→ send() → POST .../send/ {body}
→ WhatsApp* models + broadcast → provider messages → UI
```

### F12 — Logout

```
Logout
→ AuthProvider.logout()
→ POST auth/logout/ {refresh}
→ clear secure + prefs → LoginScreen
```

### F13 — Admin dashboard

```
AdminDashboardScreen
→ DashboardProvider.loadDashboardStats() → GET dashboard/
→ DonorProvider.loadAllDonors() → GET donors/
→ Tap request → BloodRequestProvider.loadRequestDetail() → GET blood-requests/{id}/
→ AdminRequestDetailSheet (display only)
```

### F14 — Create blood request

```
CreateRequestScreen submit
→ BloodRequestProvider.createRequest()
→ POST blood-requests/ {blood_group, units_needed, urgency, note, req_lat?, req_lng?, location_name?, radius_km?}
→ BloodRequestViewSet.create
→ Match donors → Notification per match → WhatsApp alert (no pool assign on API path)
→ then GET blood-requests/my_requests/ (internal)
→ pop back → dashboard refresh expected by user
```

### F15 — Token refresh

```
Any authenticated call returns 401
→ ApiClient interceptor
→ POST auth/token/refresh/ {refresh}
→ save new access → retry original
→ on failure → deleteAll tokens
```

---

## 3. API Contracts (Flutter-consumed only)

| Endpoint | Method | Auth | Request | Success shape | Flutter model | View | Serializer / models | Errors |
|----------|--------|------|---------|---------------|---------------|------|---------------------|--------|
| `auth/login/` | POST | No | `username`, `password` | `access`, `refresh`, `user`, `has_donor_profile`, `donor_profile?` | User, DonorProfile | `login_view` | UserSerializer, DonorProfileSerializer | 400, 401, 403 |
| `auth/register/` | POST | No | `username`, `email`, `password`, `password_confirm`, `first_name`, `last_name` (+ optional `phone`) | `message`, tokens, `user` | User | `register_view` | UserRegistrationSerializer → User | 400 |
| `auth/logout/` | POST | Yes | `refresh?` | `{message}` | — | `logout_view` | blacklist refresh | 401; still 200 on blacklist fail |
| `auth/me/` | GET | Yes | — | `user`, `has_donor_profile`, `donor_profile?` | User, DonorProfile | `current_user_view` | same as login | 401 |
| `auth/token/refresh/` | POST | Refresh JWT | `refresh` | `access` (+ rotated `refresh`) | — | TokenRefreshView | SimpleJWT | 401 |
| `donors/` | POST | Yes | `phone`, `blood_group`, `is_available`, `last_lat?`, `last_lng?` | create fields (create serializer) | DonorProfile | DonorProfileViewSet.create | DonorProfileCreateSerializer → DonorProfile | 400, 401 |
| `donors/update_me/` | PATCH | Yes | partial same fields | full DonorProfileSerializer | DonorProfile | update_me | Create in / Profile out | 400, 404, 401 |
| `donors/` | GET | Admin | — | paginated list (ListSerializer) | DonorProfile (mapped) | list | DonorProfileListSerializer | 401, 403 |
| `blood-requests/` | POST | Admin | group, units 1–10, urgency, note, location fields | `message`, `blood_request`, `matched_donors` | BloodRequest | create | Create → Detail | 400, 403 |
| `blood-requests/{id}/` | GET | Yes | — | Detail (+ notified/accepted donors) | BloodRequest | retrieve | BloodRequestDetailSerializer | 401, 404 |
| `blood-requests/my_requests/` | GET | Staff | — | list/paginated | BloodRequest | my_requests | BloodRequestSerializer | 401, 403 |
| `notifications/` | GET | Yes | — | paginated `{results:[...]}` or list | NotificationModel | NotificationViewSet.list | NotificationSerializer | 401 |
| `respond/` | POST | Yes | `blood_request_id`, `response` ∈ accepted\|rejected | `message`, `response` | — (reload notifs) | `respond_to_request` | DonorResponseSerializer; models DonorResponse, AdminNotification, Notification, pool | 400, 404, 401 |
| `dashboard/` | GET | Admin | — | totals + `recent_requests` | DashboardStats | `admin_dashboard` | BloodRequestSerializer for recent | 403 |
| `whatsapp/unread/` | GET | Yes | — | `{unread:int}` | int | whatsapp_unread_count | WhatsAppConversation | 401 |
| `whatsapp/conversations/` | GET | Yes | page_size? | array of conversation maps | Map (untyped) | conversations_list | WhatsAppConversationSerializer | 401 |
| `whatsapp/conversations/{id}/messages/` | GET | Yes | page, page_size | conversation + messages + paging | Map | conversation_messages | Message serializer | 403, 404 |
| `whatsapp/conversations/{id}/send/` | POST | Yes | `body` or `message` | `{ok, log_id, message_id, ...}` | — | send_message | WhatsAppMessage/Log | 400, 403, 502 |
| WS `/ws/whatsapp/donor/?token=` | WS | JWT query | — | `connected`, `chat_message`, … | — | WhatsAppDonorConsumer | Conversation must exist; non-staff | close on fail |

**Validation highlights:** password ≥8 + confirm match · units 1–10 · radius 0.1–500 · lat/lng ranges · both lat+lng if location used · urgency `critical|high|medium` · blood groups `A+`…`AB-`.

**Side effects worth testing:** create request → Notifications + WhatsApp alerts · **API create does NOT assign donor pools** (pools are web-admin path) · respond accept → AdminNotification + first-accept-wins.

---

## 4. File Dependency Maps

### Shared infra
| Layer | File |
|-------|------|
| API client | `ayh_mobile/lib/core/api/api_client.dart` |
| Constants | `ayh_mobile/lib/core/constants/api_constants.dart` |
| Storage | `ayh_mobile/lib/data/services/storage_service.dart` |
| URLs | `AYH/careapp/api_urls.py` |
| Auth/API views | `AYH/careapp/api_views.py` |
| Serializers | `AYH/careapp/serializers.py` |
| Models | `AYH/careapp/models.py` |
| WhatsApp API | `AYH/careapp/whatsapp_api.py`, `serializers_whatsapp.py`, `whatsapp_models.py` |
| WS | `AYH/careapp/consumers.py`, `routing.py`, `middleware.py` |

### Per feature (Flutter)

| Feature | Screen / widget | Provider | Repository | Service | Model |
|---------|-----------------|----------|------------|---------|-------|
| Splash | `splash_screen.dart` | — | — | — | — |
| Session | `onboarding_screen.dart` | `auth_provider` | `auth_repository` | `auth_service` | User, DonorProfile |
| Login | `login_screen.dart` | auth | auth | auth | User, DonorProfile |
| Register | `register_screen.dart`, `donor_willing_dialog.dart` | auth | auth | auth | User |
| Create profile | `create_profile_screen.dart` | donor (+ auth local) | `donor_repository` | `donor_service` | DonorProfile |
| Donor home / avail | `donor_home_screen.dart` | notification, whatsapp, donor, auth | notif, donor | notif, donor, whatsapp | Notification, DonorProfile |
| Notifications | `donor_notifications_screen.dart`, `donor_response_sheet.dart` | notification | notif + response | `notification_service`, `response_service` | Notification |
| My responses | `donor_my_responses_screen.dart` | notification (filter) | — / reload notif | notification | Notification |
| Profile | `donor_profile_screen.dart` | donor, auth | donor | donor | DonorProfile, User |
| Support chat | `support_chat_screen.dart` | `whatsapp_chat_provider` | *(none)* | `whatsapp_chat_service` | Map |
| Admin dash | `admin_dashboard_screen.dart`, `admin_request_detail_sheet.dart` | dashboard, donor, blood_request, auth | matching repos | dashboard, donor, blood_request | DashboardStats, DonorProfile, BloodRequest |
| Create request | `create_request_screen.dart` | blood_request | blood_request | blood_request | BloodRequest |

**Backend services used on active paths:** donor matching inside `BloodRequestViewSet.create`; `trigger_blood_alert_whatsapp`; `handle_donor_response_for_pool` on respond; WhatsApp send services on chat.

---

## 5. Reverse API Trace

| Endpoint | Service | Repository | Provider | Screen(s) | Journey |
|----------|---------|------------|----------|-----------|---------|
| POST auth/login/ | AuthService.login | AuthRepository | AuthProvider.login | LoginScreen | Sign in → home |
| POST auth/register/ | register | AuthRepository | register | RegisterScreen | Sign up → profile or login |
| POST auth/logout/ | logout | AuthRepository | logout | DonorHome, AdminDashboard | End session |
| GET auth/me/ | getCurrentUser | AuthRepository | checkLoginStatus | Onboarding | Restore session |
| POST auth/token/refresh/ | ApiClient | — | — | any authenticated call | Silent renew |
| POST donors/ | createProfile | DonorRepository | createProfile | CreateProfileScreen | Become donor |
| PATCH donors/update_me/ | updateMyProfile | DonorRepository | updateProfile / updateMyLocation | DonorHome, DonorProfile | Avail / GPS |
| GET donors/ | getAllDonors | DonorRepository | loadAllDonors | AdminDashboard | Admin donor list |
| POST blood-requests/ | createRequest | BloodRequestRepository | createRequest | CreateRequestScreen | Admin create |
| GET blood-requests/{id}/ | getRequestDetail | BloodRequestRepository | loadRequestDetail | AdminDashboard | Detail sheet |
| GET blood-requests/my_requests/ | getMyRequests | BloodRequestRepository | inside createRequest | CreateRequestScreen (indirect) | Post-create refresh |
| GET notifications/ | getMyNotifications | NotificationRepository | loadNotifications | DonorHome, Notifications, MyResponses reload | Alerts |
| POST respond/ | ResponseService | NotificationRepository | respondToRequest | DonorNotifications (+ sheet) | Accept/decline |
| GET dashboard/ | getDashboardStats | DashboardRepository | loadDashboardStats | AdminDashboard | KPIs |
| GET whatsapp/unread/ | fetchUnreadCount | — | loadUnread | DonorHome, chat internals | Badge |
| GET whatsapp/conversations/ | fetchConversations | — | initChat | SupportChat | Open thread |
| GET …/messages/ | fetchMessages | — | initChat / send reload | SupportChat | History |
| POST …/send/ | sendMessage | — | send | SupportChat | Send text |
| WS donor | connectWebSocket | — | initChat | SupportChat | Live updates |

**Implemented in Flutter but NOT on active screen path:** `GET donors/me/` (`DonorProvider.loadMyProfile` never called from UI). Profile comes from login/me/create/update cache.

---

## 6. Flutter Data Models

```
Django User → UserSerializer → {id, username, email, first_name, last_name, is_staff}
  → Flutter User → Login, Register, Session, Profile, Admin gates (is_staff)

DonorProfile → DonorProfileSerializer → {id, user, username, phone, blood_group, is_available, created_at, last_lat, last_lng, location_updated_at}
  → Flutter DonorProfile → CreateProfile, Home toggle, Profile, Admin donor list

BloodRequest → BloodRequestSerializer / DetailSerializer → group, units, urgency, note, geo, counts, notified/accepted donors…
  → Flutter BloodRequest → nested in Notification; Admin detail; Create; Dashboard recent

Notification → NotificationSerializer → {id, blood_request, is_read, created_at, has_responded, response_status, responded_at, distance_km}
  → Flutter NotificationModel → Home, Notifications, MyResponses

Dashboard JSON → {total_requests, active_requests, total_donors, available_donors, total_accepted, critical_requests, recent_requests}
  → Flutter DashboardStats → AdminDashboard

WhatsAppConversation / WhatsAppMessage → serializers_whatsapp → JSON maps
  → Flutter: untyped Map/List in WhatsAppChatProvider → SupportChatScreen
```

---

## 7. Runtime Dependencies

| Feature | Needs |
|---------|--------|
| All API | Django on `:8000`, correct base URL, network/cleartext |
| Auth / session | JWT, flutter_secure_storage, SharedPreferences, Dio Bearer + 401 refresh |
| Register → profile | Successful register tokens; CreateProfile; optional Geolocator permission |
| Donor home | Logged-in user; ideally DonorProfile; notifications API |
| Respond | DonorProfile + Notification for that user; open BloodRequest; no prior other acceptor |
| Admin dashboard / create | `is_staff` / admin user; create needs available compatible donors for “notified” |
| Create request side effects | Donor matching + Notification rows; WhatsApp config optional (fail soft) |
| Support chat | Access token; WS URL derived from API host; donor conversation (auto get_or_create if phone); Redis/Channels may matter in prod |
| Location update | Location permission + PATCH update_me |

---

## 8. Manual Testing Checklist (for Phase 5)

### Splash / session
- [ ] Splash → Onboarding every cold start  
- [ ] Skip/Get Started → if tokens valid, GET auth/me succeeds  
- [ ] Staff → AdminDashboard; donor → DonorHome; else Login  
- [ ] Invalid/expired refresh → ends on Login  

### Login / logout
- [ ] Valid credentials → tokens in secure storage  
- [ ] Wrong password → error UI, stay on Login  
- [ ] Logout → POST logout, storage cleared, Login shown  

### Register / create profile
- [ ] Register validation (password mismatch / short) shows errors  
- [ ] Success → Willing dialog  
- [ ] Willing → CreateProfile → POST donors/ 201 → DonorHome  
- [ ] Decline → Login  

### Donor home
- [ ] Notifications load (paginated `results` handled)  
- [ ] WhatsApp unread badge loads  
- [ ] Availability toggle → PATCH update_me → UI syncs  

### Notifications / respond
- [ ] List shows blood request details  
- [ ] Accept → POST respond → status updates; admin can see acceptance path  
- [ ] Second donor cannot accept same request (400)  
- [ ] Reject works; list refreshes  

### My responses
- [ ] Shows only `hasResponded` items from memory  
- [ ] Does not newly POST respond from this screen  

### Profile
- [ ] Shows cached user/donor  
- [ ] Update location → PATCH → coords saved  

### Support chat
- [ ] Conversations + messages load  
- [ ] WS connects (`connected` event)  
- [ ] Send message appears; unread updates  

### Admin
- [ ] Dashboard stats + recent requests  
- [ ] Donor list loads (admin only; 403 as donor)  
- [ ] Request detail sheet loads notified/accepted  
- [ ] Create request → 201 → donors notified → donor app shows notification  

### Infra
- [ ] Force 401 → refresh → retry succeeds  
- [ ] Backend down → graceful error (no crash)  

---

## 9. Unknowns / Risks

| Item | What we know statically |
|------|-------------------------|
| POST `donors/` response | Backend returns **CreateSerializer** fields only; Flutter `DonorProfile.fromJson` expects `id` etc. May yield incomplete profile until next `auth/me` / update — **verify at runtime** |
| `GET donors/me/` | Implemented backend + Flutter service/provider; **no active screen calls `loadMyProfile`** |
| mark_read APIs | Flutter methods exist; **screens never call them** (respond marks read server-side) |
| Blood request list/update/delete | Flutter provider methods unused by UI |
| Donor pools | `/api/requests/<id>/donor-pools/` unused by Flutter; API create request **does not** assign pools |
| MyResponses Accept/Decline | Sheet present but `onRespond` only reloads list — **cannot newly respond here** |
| WhatsApp without Redis | Local InMemory channel layer may work; multi-process unknown |
| JWT blacklist | Logout blacklist may no-op if blacklist app missing — logout still returns 200 |
| Pagination | Notifications/donors lists: Flutter handles `results`; only first page loaded |
| CreateRequest → dashboard | After create, depends on user returning and dashboard reload — confirm UI refresh behavior live |
| Landing/Intro | Dead routes — ignore in E2E |
| Production URL | Not wired; local-only defaults |

---

## How to use this doc next

- **Phase 3:** Unblock Android build (env/Gradle); do not change feature contracts.  
- **Phase 4:** Launch with Django `:8000` + this dependency table.  
- **Phase 5:** Run Section 8 checklists journey-by-journey; log failures against Section 3 contracts.  
- **Phase 6:** Delete inactive screens/unused provider methods only after Phase 5 passes.

**One-line:** Active Blood450 mobile = JWT auth + donor profile/location + notifications/respond + admin dashboard/create request + WhatsApp REST/WS; everything else is unused or web-only.
