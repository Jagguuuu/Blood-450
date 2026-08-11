# 🚀 Blood Donation System - REST API Documentation

## Base URL
```
Development: http://127.0.0.1:8000/api/
Production: https://yourdomain.com/api/
```

---

## 🔐 Authentication

The API uses **JWT (JSON Web Tokens)** for authentication.

### How It Works:
1. Login with username/password
2. Receive `access` and `refresh` tokens
3. Include `access` token in all subsequent requests
4. Refresh token when it expires

### Token Lifetimes:
- **Access Token**: 1 hour
- **Refresh Token**: 7 days

---

## 📡 API Endpoints

### **1. AUTHENTICATION**

#### 1.1 Login
```http
POST /api/auth/login/
```

**Request Body:**
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**Response (200 OK):**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "first_name": "Admin",
    "last_name": "User",
    "is_staff": true
  },
  "has_donor_profile": false,
  "donor_profile": null
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": "Invalid credentials"
}
```

---

#### 1.2 Register
```http
POST /api/auth/register/
```

**Request Body:**
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "securepass123",
  "password_confirm": "securepass123",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response (201 Created):**
```json
{
  "message": "User registered successfully",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 2,
    "username": "john_doe",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "is_staff": false
  }
}
```

---

#### 1.3 Refresh Token
```http
POST /api/auth/token/refresh/
```

**Request Body:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Response (200 OK):**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

---

#### 1.4 Get Current User
```http
GET /api/auth/me/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "is_staff": true
  },
  "has_donor_profile": false,
  "donor_profile": null
}
```

---

#### 1.5 Logout
```http
POST /api/auth/logout/
Authorization: Bearer {access_token}
```

**Request Body:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Response (200 OK):**
```json
{
  "message": "Logout successful"
}
```

---

### **2. DONOR PROFILE**

#### 2.1 Get My Profile
```http
GET /api/donors/me/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "user": {
    "id": 2,
    "username": "john_donor",
    "email": "john@example.com",
    "is_staff": false
  },
  "username": "john_donor",
  "phone": "+1234567890",
  "blood_group": "A+",
  "is_available": true,
  "created_at": "2026-01-25T10:30:00"
}
```

---

#### 2.2 Create Donor Profile
```http
POST /api/donors/
Authorization: Bearer {access_token}
```

**Request Body:**
```json
{
  "phone": "+1234567890",
  "blood_group": "A+",
  "is_available": true
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "phone": "+1234567890",
  "blood_group": "A+",
  "is_available": true
}
```

---

#### 2.3 Update My Profile
```http
PUT /api/donors/update_me/
Authorization: Bearer {access_token}
```

**Request Body:**
```json
{
  "phone": "+1987654321",
  "is_available": false
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "phone": "+1987654321",
  "blood_group": "A+",
  "is_available": false,
  "created_at": "2026-01-25T10:30:00"
}
```

---

#### 2.4 List All Donors (Admin Only)
```http
GET /api/donors/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "count": 10,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "username": "john_donor",
      "email": "john@example.com",
      "phone": "+1234567890",
      "blood_group": "A+",
      "is_available": true,
      "created_at": "2026-01-25T10:30:00"
    }
  ]
}
```

---

### **3. BLOOD REQUESTS**

#### 3.1 List All Blood Requests
```http
GET /api/blood-requests/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "count": 5,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "blood_group": "A+",
      "units_needed": 2,
      "urgency": "critical",
      "urgency_display": "Critical",
      "note": "Urgent surgery tomorrow",
      "created_by": 1,
      "created_by_username": "admin",
      "is_active": true,
      "created_at": "2026-01-25T10:30:00",
      "notified_count": 3,
      "accepted_count": 1
    }
  ]
}
```

---

#### 3.2 Get Blood Request Details
```http
GET /api/blood-requests/{id}/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "blood_group": "A+",
  "units_needed": 2,
  "urgency": "critical",
  "urgency_display": "Critical",
  "note": "Urgent surgery tomorrow",
  "created_by": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "is_staff": true
  },
  "is_active": true,
  "created_at": "2026-01-25T10:30:00",
  "notified_donors": [
    {
      "id": 2,
      "username": "john_donor",
      "blood_group": "A+",
      "notified_at": "2026-01-25T10:30:01"
    }
  ],
  "accepted_donors": [
    {
      "id": 2,
      "username": "john_donor",
      "phone": "+1234567890",
      "blood_group": "A+",
      "responded_at": "2026-01-25T10:35:00"
    }
  ]
}
```

---

#### 3.3 Create Blood Request (Admin Only)
```http
POST /api/blood-requests/
Authorization: Bearer {access_token}
```

**Request Body:**
```json
{
  "blood_group": "A+",
  "units_needed": 2,
  "urgency": "critical",
  "note": "Urgent surgery tomorrow"
}
```

**Response (201 Created):**
```json
{
  "message": "Blood request created successfully! 3 compatible donor(s) notified.",
  "blood_request": {
    "id": 1,
    "blood_group": "A+",
    "units_needed": 2,
    "urgency": "critical",
    "urgency_display": "Critical",
    "note": "Urgent surgery tomorrow",
    "created_by": {
      "id": 1,
      "username": "admin"
    },
    "is_active": true,
    "created_at": "2026-01-25T10:30:00",
    "notified_donors": [],
    "accepted_donors": []
  }
}
```

---

#### 3.4 Get Active Requests Only
```http
GET /api/blood-requests/active/
Authorization: Bearer {access_token}
```

---

#### 3.5 Get My Requests (Admin Only)
```http
GET /api/blood-requests/my_requests/
Authorization: Bearer {access_token}
```

---

### **4. NOTIFICATIONS**

#### 4.1 Get My Notifications
```http
GET /api/notifications/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "count": 2,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "blood_request": {
        "id": 1,
        "blood_group": "A+",
        "units_needed": 2,
        "urgency": "critical",
        "urgency_display": "Critical",
        "note": "Urgent surgery tomorrow",
        "created_by_username": "admin",
        "created_at": "2026-01-25T10:30:00",
        "notified_count": 3,
        "accepted_count": 1
      },
      "is_read": false,
      "created_at": "2026-01-25T10:30:01",
      "has_responded": false,
      "response_status": null
    }
  ]
}
```

---

#### 4.2 Mark Notification as Read
```http
POST /api/notifications/{id}/mark_read/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "message": "Notification marked as read"
}
```

---

#### 4.3 Mark All Notifications as Read
```http
POST /api/notifications/mark_all_read/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "message": "5 notifications marked as read"
}
```

---

### **5. DONOR RESPONSE**

#### 5.1 Respond to Blood Request
```http
POST /api/respond/
Authorization: Bearer {access_token}
```

**Request Body:**
```json
{
  "blood_request_id": 1,
  "response": "accepted"
}
```

**Response (200 OK):**
```json
{
  "message": "Response created successfully",
  "response": {
    "id": 1,
    "blood_request": {
      "id": 1,
      "blood_group": "A+",
      "units_needed": 2,
      "urgency": "critical"
    },
    "donor": {
      "id": 2,
      "username": "john_donor"
    },
    "response": "accepted",
    "response_display": "Accepted",
    "responded_at": "2026-01-25T10:35:00"
  }
}
```

**Valid Response Values:**
- `"accepted"` - Donor accepts the request
- `"rejected"` - Donor rejects the request

---

### **6. DASHBOARD**

#### 6.1 Get Admin Dashboard Stats (Admin Only)
```http
GET /api/dashboard/
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "total_requests": 10,
  "active_requests": 5,
  "total_donors": 25,
  "available_donors": 20,
  "total_accepted": 15,
  "critical_requests": 2,
  "recent_requests": [
    {
      "id": 1,
      "blood_group": "A+",
      "units_needed": 2,
      "urgency": "critical",
      "created_at": "2026-01-25T10:30:00"
    }
  ]
}
```

---

## 🔒 Authorization Header

All authenticated endpoints require JWT token in header:

```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
```

---

## 📊 Blood Group Compatibility

The API automatically notifies compatible donors based on blood compatibility rules:

| Request | Compatible Donors |
|---------|------------------|
| A+ | A+, A-, O+, O- |
| A- | A-, O- |
| B+ | B+, B-, O+, O- |
| B- | B-, O- |
| AB+ | **All blood types** (universal receiver) |
| AB- | A-, B-, AB-, O- |
| O+ | O+, O- |
| O- | O- only |

---

## ⚠️ Error Responses

### 400 Bad Request
```json
{
  "error": "Invalid data",
  "details": {
    "field_name": ["Error message"]
  }
}
```

### 401 Unauthorized
```json
{
  "detail": "Authentication credentials were not provided."
}
```

### 403 Forbidden
```json
{
  "detail": "You do not have permission to perform this action."
}
```

### 404 Not Found
```json
{
  "detail": "Not found."
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error"
}
```

---

## 🧪 Testing the API

### Using cURL:

```bash
# Login
curl -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Get notifications (with token)
curl -X GET http://127.0.0.1:8000/api/notifications/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Using Postman:
1. Import collection from this documentation
2. Set `Authorization` type to `Bearer Token`
3. Paste access token

### Using Browser:
Navigate to: `http://127.0.0.1:8000/api/`

You'll see the **Browsable API** interface for testing.

---

## 📱 Flutter Integration

### Example Dio Client Setup:

```dart
import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:8000/api/',  // Android emulator
    connectTimeout: Duration(seconds: 5),
    receiveTimeout: Duration(seconds: 3),
  ));
  
  String? _accessToken;
  
  void setToken(String token) {
    _accessToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
  
  Future<Response> login(String username, String password) async {
    return await _dio.post('/auth/login/', data: {
      'username': username,
      'password': password,
    });
  }
  
  Future<Response> getNotifications() async {
    return await _dio.get('/notifications/');
  }
}
```

---

## 🚀 Next Steps

1. **Install dependencies**: `pip install -r requirements.txt`
2. **Run migrations**: `python manage.py migrate`
3. **Create superuser**: `python manage.py createsuperuser`
4. **Start server**: `python manage.py runserver`
5. **Test API**: Visit `http://127.0.0.1:8000/api/`

---

**API is ready for Flutter integration!** 🎉
