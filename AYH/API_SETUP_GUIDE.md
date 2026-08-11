# 🚀 REST API Setup Guide

## ✅ What Was Added

Your Django backend now has a **complete REST API** for Flutter integration while keeping all existing web templates working!

### New Features:
- ✅ JWT Authentication (stateless tokens)
- ✅ RESTful API endpoints
- ✅ CORS support for mobile apps
- ✅ Blood compatibility logic (same as web)
- ✅ Browsable API for testing
- ✅ Token refresh mechanism
- ✅ Rate limiting
- ✅ Pagination

---

## 📦 Installation Steps

### Step 1: Install Dependencies

```bash
pip install -r requirements.txt
```

This installs:
- `djangorestframework` - REST API framework
- `djangorestframework-simplejwt` - JWT authentication
- `django-cors-headers` - CORS support for Flutter

---

### Step 2: Run Migrations

The API uses your existing models, but JWT needs token blacklist tables:

```bash
python manage.py migrate
```

---

### Step 3: Create Test Users (If Needed)

If you don't have users yet:

```bash
# Create admin user
python manage.py createsuperuser

# Or use existing demo script
python create_demo_users.py
```

---

### Step 4: Start Server

```bash
python manage.py runserver
```

---

## 🧪 Testing the API

### Option 1: Browsable API (Easiest)

1. Start server: `python manage.py runserver`
2. Open browser: `http://127.0.0.1:8000/api/`
3. You'll see a beautiful web interface to test all endpoints!

**Features:**
- ✅ Interactive forms
- ✅ Try API calls directly in browser
- ✅ See request/response
- ✅ Login with session auth

---

### Option 2: Using Postman/Insomnia

#### Step 1: Login
```http
POST http://127.0.0.1:8000/api/auth/login/
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}
```

**Copy the `access` token from response**

#### Step 2: Use Token
```http
GET http://127.0.0.1:8000/api/notifications/
Authorization: Bearer YOUR_ACCESS_TOKEN_HERE
```

---

### Option 3: Using cURL

```bash
# Login and save token
curl -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  | jq -r '.access'

# Use token (replace YOUR_TOKEN)
curl -X GET http://127.0.0.1:8000/api/notifications/ \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 📱 Testing with Flutter

### For Android Emulator:
```dart
baseUrl: 'http://10.0.2.2:8000/api/'
```

### For Physical Device:
1. Find your computer's IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
2. Update `ALLOWED_HOSTS` in `settings.py`:
   ```python
   ALLOWED_HOSTS = ['localhost', '127.0.0.1', '192.168.1.100']  # Your IP
   ```
3. Run server: `python manage.py runserver 0.0.0.0:8000`
4. Use in Flutter: `http://192.168.1.100:8000/api/`

---

## 🔍 API Endpoints Quick Reference

### Authentication
- `POST /api/auth/login/` - Login (get JWT tokens)
- `POST /api/auth/register/` - Register new user
- `POST /api/auth/token/refresh/` - Refresh access token
- `GET /api/auth/me/` - Get current user info
- `POST /api/auth/logout/` - Logout (blacklist token)

### Donor Profile
- `GET /api/donors/me/` - Get my profile
- `POST /api/donors/` - Create profile
- `PUT /api/donors/update_me/` - Update my profile
- `GET /api/donors/` - List all donors (admin only)

### Blood Requests
- `GET /api/blood-requests/` - List all requests
- `POST /api/blood-requests/` - Create request (admin)
- `GET /api/blood-requests/{id}/` - Get details
- `GET /api/blood-requests/active/` - Active requests only

### Notifications
- `GET /api/notifications/` - My notifications
- `POST /api/notifications/{id}/mark_read/` - Mark as read
- `POST /api/notifications/mark_all_read/` - Mark all read

### Responses
- `POST /api/respond/` - Accept/reject blood request

### Dashboard
- `GET /api/dashboard/` - Admin statistics (admin only)

---

## 🎯 Common Use Cases

### Use Case 1: Donor Login Flow

```python
# 1. Login
POST /api/auth/login/
{
  "username": "john_donor",
  "password": "donor123"
}

# Response includes:
# - access token (use for 1 hour)
# - refresh token (use to get new access token)
# - user info
# - donor profile (if exists)

# 2. Get notifications
GET /api/notifications/
Authorization: Bearer {access_token}

# 3. Respond to request
POST /api/respond/
Authorization: Bearer {access_token}
{
  "blood_request_id": 1,
  "response": "accepted"
}
```

---

### Use Case 2: Admin Create Request Flow

```python
# 1. Login as admin
POST /api/auth/login/
{
  "username": "admin",
  "password": "admin123"
}

# 2. Create blood request
POST /api/blood-requests/
Authorization: Bearer {access_token}
{
  "blood_group": "A+",
  "units_needed": 2,
  "urgency": "critical",
  "note": "Urgent surgery"
}

# System automatically:
# - Finds compatible donors (A+, A-, O+, O-)
# - Creates notifications
# - Returns count of notified donors

# 3. View request details
GET /api/blood-requests/1/
Authorization: Bearer {access_token}

# Shows:
# - Request info
# - List of notified donors
# - List of accepted donors with contact info
```

---

### Use Case 3: Token Refresh

```python
# When access token expires (after 1 hour):

POST /api/auth/token/refresh/
{
  "refresh": "your_refresh_token"
}

# Response:
{
  "access": "new_access_token",
  "refresh": "new_refresh_token"
}

# Update your stored tokens and continue
```

---

## 🔒 Security Features

### ✅ Implemented:
- JWT authentication (stateless)
- Token expiration (1 hour access, 7 days refresh)
- Token rotation on refresh
- Token blacklisting on logout
- CORS protection
- Rate limiting (100/hour anonymous, 1000/hour authenticated)
- Password hashing
- CSRF protection (for web interface)

### 🔐 For Production:
1. Set `DEBUG = False`
2. Set `DJANGO_ENV=production` environment variable
3. Use HTTPS
4. Update `ALLOWED_HOSTS`
5. Update `CORS_ALLOWED_ORIGINS`
6. Use PostgreSQL instead of SQLite
7. Set strong `SECRET_KEY` via environment variable

---

## 🐛 Troubleshooting

### Issue 1: CORS Error in Flutter
**Error:** `Access to XMLHttpRequest has been blocked by CORS policy`

**Solution:**
- In development, `CORS_ALLOW_ALL_ORIGINS = True` is already set
- For production, add your domain to `CORS_ALLOWED_ORIGINS`

---

### Issue 2: Token Expired
**Error:** `{"detail":"Given token not valid for any token type"}`

**Solution:**
- Use refresh token to get new access token
- Call `/api/auth/token/refresh/` with refresh token

---

### Issue 3: Can't Connect from Physical Device
**Error:** Connection timeout

**Solution:**
1. Find your PC's IP address
2. Add to `ALLOWED_HOSTS` in settings.py
3. Run server: `python manage.py runserver 0.0.0.0:8000`
4. Make sure firewall allows port 8000

---

### Issue 4: Import Error
**Error:** `ModuleNotFoundError: No module named 'rest_framework'`

**Solution:**
```bash
pip install -r requirements.txt
```

---

## 📊 What's Different from Web Version?

| Feature | Web Version | API Version |
|---------|-------------|-------------|
| **Authentication** | Session cookies | JWT tokens |
| **Response Format** | HTML pages | JSON |
| **CSRF** | Required | Not required (JWT) |
| **State** | Server-side | Stateless |
| **Mobile Support** | Limited | Full support |
| **Offline** | No | Possible with caching |

**Important:** Both versions use the **same database** and **same business logic**!

---

## ✅ Verification Checklist

Test these to confirm API is working:

- [ ] Can access browsable API: `http://127.0.0.1:8000/api/`
- [ ] Can login and get JWT token
- [ ] Can access protected endpoint with token
- [ ] Token refresh works
- [ ] Blood request creation notifies compatible donors
- [ ] Donor can accept/reject requests
- [ ] Admin dashboard returns statistics
- [ ] Web interface still works: `http://127.0.0.1:8000/`

---

## 🎉 You're Ready!

Your Django backend is now **API-ready** for Flutter development!

**Next Steps:**
1. ✅ Test all endpoints using browsable API
2. ✅ Read `API_DOCUMENTATION.md` for detailed endpoint info
3. ✅ Start building Flutter app
4. ✅ Use Dio package for HTTP requests
5. ✅ Implement JWT token management in Flutter

---

## 📞 Need Help?

- **Browsable API**: `http://127.0.0.1:8000/api/` (interactive testing)
- **API Docs**: See `API_DOCUMENTATION.md`
- **Django REST Framework Docs**: https://www.django-rest-framework.org/

---

**Your backend is production-ready for mobile apps!** 🚀
