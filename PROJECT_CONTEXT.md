# 🎯 PROJECT CONTEXT - AYH Blood Donation System

## 📋 OVERVIEW

This is a **full-stack blood donation management system** with:
- **Backend**: Django REST API (Python)
- **Frontend**: Flutter Mobile App (Dart/Android)
- **Database**: SQLite (dev) / PostgreSQL (production)
- **Authentication**: JWT tokens

---

## 🏗️ PROJECT STRUCTURE

```
AYH/
├── AYH/                          # Django Backend (REST API)
│   ├── careapp/                  # Main Django app
│   │   ├── models.py             # 4 models: DonorProfile, BloodRequest, Notification, DonorResponse
│   │   ├── views.py              # Web views (Django templates)
│   │   ├── api_views.py          # REST API endpoints (23 endpoints)
│   │   ├── serializers.py        # JSON serializers for API
│   │   └── api_urls.py           # API routing
│   ├── templates/                # Django HTML templates (keep for web interface)
│   ├── manage.py                 # Django management
│   └── requirements.txt          # Python dependencies
│
└── ayh_mobile/                   # Flutter Mobile App
    ├── lib/                      # Dart source code
    │   ├── main.dart             # App entry point
    │   ├── core/                 # Core functionality (API, constants, utils)
    │   ├── data/                 # Models, repositories, services
    │   ├── presentation/         # Screens, widgets, providers
    │   └── routes/               # Navigation
    ├── android/                  # Android platform code
    └── pubspec.yaml              # Flutter dependencies
```

---

## 🎯 PROJECT GOALS

### **What We're Building:**
A mobile app (Flutter) that connects to Django backend API for blood donation management.

### **Key Features:**
1. **Admin Features** (Staff users):
   - Create blood donation requests
   - View dashboard with statistics
   - See which donors accepted requests
   - Get donor contact information

2. **Donor Features** (Regular users):
   - Receive notifications for blood requests
   - Accept or reject donation requests
   - View their donation history
   - Update profile (blood group, availability)

3. **System Features**:
   - Blood compatibility matching (O- universal donor, AB+ universal receiver, etc.)
   - JWT authentication (stateless, mobile-friendly)
   - Real-time notifications
   - Secure token management

---

## 🔐 AUTHENTICATION FLOW

```
1. User logs in via Flutter app
   ↓
2. Django API returns JWT tokens:
   - access token (1 hour)
   - refresh token (7 days)
   ↓
3. Flutter stores tokens securely
   ↓
4. All API requests include: Authorization: Bearer {access_token}
   ↓
5. When token expires, use refresh token to get new access token
```

---

## 📡 API ENDPOINTS (23 Total)

### **Authentication (5 endpoints):**
- `POST /api/auth/login/` - Login with username/password
- `POST /api/auth/register/` - Register new user
- `POST /api/auth/token/refresh/` - Refresh access token
- `GET /api/auth/me/` - Get current user info
- `POST /api/auth/logout/` - Logout (blacklist token)

### **Donor Profile (5 endpoints):**
- `GET /api/donors/me/` - Get my profile
- `POST /api/donors/` - Create donor profile
- `PUT /api/donors/update_me/` - Update my profile
- `GET /api/donors/` - List all donors (admin only)
- `GET /api/donors/{id}/` - Get specific donor

### **Blood Requests (7 endpoints):**
- `GET /api/blood-requests/` - List all requests
- `POST /api/blood-requests/` - Create request (admin only)
- `GET /api/blood-requests/{id}/` - Get request details
- `PUT /api/blood-requests/{id}/` - Update request (admin)
- `DELETE /api/blood-requests/{id}/` - Delete request (admin)
- `GET /api/blood-requests/active/` - Active requests only
- `GET /api/blood-requests/my_requests/` - My requests (admin)

### **Notifications (4 endpoints):**
- `GET /api/notifications/` - My notifications
- `GET /api/notifications/{id}/` - Notification details
- `POST /api/notifications/{id}/mark_read/` - Mark as read
- `POST /api/notifications/mark_all_read/` - Mark all read

### **Responses (1 endpoint):**
- `POST /api/respond/` - Accept/reject blood request

### **Dashboard (1 endpoint):**
- `GET /api/dashboard/` - Admin statistics

---

## 🩸 BLOOD COMPATIBILITY LOGIC

The system automatically notifies compatible donors based on medical blood compatibility rules:

| Request | Compatible Donors Notified |
|---------|---------------------------|
| A+ | A+, A-, O+, O- |
| A- | A-, O- |
| B+ | B+, B-, O+, O- |
| B- | B-, O- |
| AB+ | **ALL blood types** (universal receiver) |
| AB- | A-, B-, AB-, O- |
| O+ | O+, O- |
| O- | O- only |

**Example:**
- Admin creates request for A+ blood
- System automatically finds and notifies: A+, A-, O+, O- donors
- Donors receive notification on Flutter app
- Donors can accept/reject with one tap

---

## 🔄 TYPICAL USER FLOW

### **Admin Flow:**
```
1. Login via Flutter app
2. Navigate to "Create Request" screen
3. Enter: Blood Group (A+), Units (2), Urgency (Critical), Note
4. Submit
5. Backend automatically notifies compatible donors
6. Admin sees: "3 compatible donors notified"
7. Admin can view accepted donors with phone numbers
```

### **Donor Flow:**
```
1. Login via Flutter app
2. See notification: "Critical blood request for A+ needed"
3. View details: Units needed, Urgency, Hospital note
4. Tap "Accept & Donate" or "Can't Donate"
5. Response sent to backend
6. Admin sees donor accepted with contact info
```

---

## 🛠️ CURRENT STATUS

### **✅ COMPLETED:**
- Django backend with REST API (fully functional)
- JWT authentication (working)
- Blood compatibility logic (working)
- CORS support for mobile (enabled)
- API documentation (complete)
- Django templates (working - keep for web interface)
- Flutter project created (basic structure)

### **🔨 IN PROGRESS:**
- Flutter app implementation
- UI/UX design for mobile screens
- API integration in Flutter
- State management setup

### **⏭️ TODO:**
- Implement Flutter screens (login, dashboard, notifications)
- Set up Dio HTTP client for API calls
- Implement JWT token management in Flutter
- Create reusable widgets (buttons, cards, badges)
- Add state management (Provider/Riverpod)
- Build navigation flow
- Implement offline support (optional)
- Add push notifications (FCM - optional)

---

## 🎨 FLUTTER APP STRUCTURE (Planned)

```
lib/
├── main.dart                     # App entry point
├── core/
│   ├── api/
│   │   ├── api_client.dart       # Dio HTTP client
│   │   └── api_endpoints.dart    # API URLs
│   ├── constants/
│   │   ├── colors.dart           # App colors
│   │   └── api_constants.dart    # Base URL, endpoints
│   └── utils/
│       └── validators.dart       # Form validation
├── data/
│   ├── models/
│   │   ├── user.dart             # User model
│   │   ├── donor_profile.dart    # Donor profile model
│   │   ├── blood_request.dart    # Blood request model
│   │   └── notification.dart     # Notification model
│   ├── repositories/
│   │   ├── auth_repository.dart  # Auth logic
│   │   └── blood_repository.dart # Blood request logic
│   └── services/
│       ├── auth_service.dart     # Auth API calls
│       └── storage_service.dart  # Token storage
├── presentation/
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── admin/
│   │   │   ├── admin_dashboard.dart
│   │   │   └── create_request_screen.dart
│   │   └── donor/
│   │       ├── notifications_screen.dart
│   │       └── profile_screen.dart
│   ├── widgets/
│   │   ├── custom_button.dart
│   │   └── notification_card.dart
│   └── providers/
│       ├── auth_provider.dart    # Auth state
│       └── notification_provider.dart
└── routes/
    └── app_routes.dart           # Navigation
```

---

## 🔌 API CONNECTION

### **Base URLs:**
```dart
// Android Emulator
baseUrl: 'http://10.0.2.2:8000/api/'

// iOS Simulator
baseUrl: 'http://localhost:8000/api/'

// Physical Device
baseUrl: 'http://YOUR_PC_IP:8000/api/'
```

### **Example API Call:**
```dart
// Login
POST http://10.0.2.2:8000/api/auth/login/
Body: {
  "username": "admin",
  "password": "admin123"
}

Response: {
  "access": "eyJ0eXAiOiJKV1Q...",
  "refresh": "eyJ0eXAiOiJKV1Q...",
  "user": {...}
}
```

---

## 🎯 DEVELOPMENT WORKFLOW

### **Running Both Projects:**

**Terminal 1 (Django Backend):**
```bash
cd AYH
python manage.py runserver
# Backend runs on: http://127.0.0.1:8000
```

**Terminal 2 (Flutter App):**
```bash
cd ayh_mobile
flutter run
# App runs on Android emulator/device
```

### **Testing:**
- **Test Django API**: http://127.0.0.1:8000/api/ (Browsable API)
- **Test Flutter**: `flutter run` or press F5

---

## 📚 KEY DOCUMENTATION FILES

- `API_DOCUMENTATION.md` - Complete API reference with examples
- `API_SETUP_GUIDE.md` - Backend setup instructions
- `FLUTTER_SETUP_GUIDE.md` - Flutter setup instructions
- `REST_API_COMPLETE.md` - API implementation summary
- `FIXES_APPLIED.md` - Backend bug fixes (blood matching, security)

---

## 🎨 DESIGN NOTES

### **Color Scheme:**
- Primary: Red/Crimson (blood theme)
- Accent: Purple/Blue gradients
- Success: Green
- Warning: Orange
- Critical: Red (pulsing animation)

### **UI Components:**
- Blood group badges (colored by type)
- Urgency badges (color-coded: red=critical, orange=high, blue=medium)
- Notification cards (with accept/reject buttons)
- Dashboard stats cards (with gradients)

---

## 🔒 SECURITY CONSIDERATIONS

### **Implemented:**
- JWT authentication (stateless)
- Token refresh mechanism
- CSRF protection (web interface)
- Password hashing
- Rate limiting (100/hour anon, 1000/hour auth)
- CORS configuration

### **TODO for Production:**
- Set `DEBUG = False`
- Use environment variables for secrets
- Enable HTTPS
- Implement token blacklist cleanup
- Add input validation on all endpoints
- Set up proper logging

---

## 🐛 KNOWN ISSUES

### **Fixed:**
- ✅ Blood group matching bug (was notifying all donors - FIXED)
- ✅ Blood compatibility logic (added medical compatibility rules)
- ✅ CSRF cookie security (now environment-aware)

### **Current:**
- None - backend is stable and working

### **Future Enhancements:**
- Real-time push notifications (Firebase Cloud Messaging)
- SMS notifications (Twilio integration)
- Email notifications
- Blood bank inventory management
- Appointment scheduling
- Donor badges/gamification
- Multi-hospital support

---

## 💡 AI ASSISTANT GUIDELINES

When helping with this project:

1. **Backend (Django)**: Located in `AYH/` folder
   - All API code is in `careapp/api_views.py` and `careapp/serializers.py`
   - Don't modify existing models unless necessary
   - Keep web templates (they still work alongside API)

2. **Frontend (Flutter)**: Located in `ayh_mobile/` folder
   - Use Dio for HTTP requests
   - Implement Provider/Riverpod for state management
   - Follow the planned folder structure
   - Connect to Django API endpoints

3. **Key Principles:**
   - Backend and frontend are separate but connected via REST API
   - Backend uses JWT tokens (not sessions) for mobile
   - Blood compatibility logic is in Django - Flutter just displays results
   - Both projects use same database

4. **When Creating Flutter Code:**
   - Always include error handling
   - Store JWT tokens securely (flutter_secure_storage)
   - Handle token refresh automatically
   - Show loading states
   - Provide user feedback (snackbars, dialogs)

5. **When Modifying Backend:**
   - Don't break existing API endpoints
   - Keep backward compatibility
   - Update API documentation if adding new endpoints
   - Test with browsable API first

---

## 🚀 NEXT IMMEDIATE TASKS

1. **Set up Dio HTTP client in Flutter**
2. **Create API client class**
3. **Implement login screen UI**
4. **Add JWT token storage**
5. **Create authentication flow**
6. **Build notifications screen**
7. **Implement accept/reject functionality**

---

## 📞 QUICK REFERENCE

### **Django Commands:**
```bash
python manage.py runserver        # Start server
python manage.py migrate          # Run migrations
python manage.py createsuperuser  # Create admin
```

### **Flutter Commands:**
```bash
flutter run                       # Run app
flutter pub get                   # Install packages
flutter build apk                 # Build Android APK
flutter doctor                    # Check setup
```

### **Test Credentials:**
```
Admin: admin / admin123
Donor: john_donor / donor123
```

---

**This workspace contains both Django backend and Flutter frontend for the AYH Blood Donation System. Both projects work together via REST API with JWT authentication.** 🩸
