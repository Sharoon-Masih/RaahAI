# Login Flow Troubleshooting Guide

## ✅ Fixed Issues

### 1. Firebase Credentials File
- **Problem**: File was named `firebase_cred.json.json` (double extension)
- **Solution**: Renamed to `firebase_cred.json`
- **Status**: ✅ FIXED - Backend now initializes Firebase successfully

### 2. Backend Configuration
- **Path**: `.env` file correctly points to credentials
- **Status**: ✅ Firebase Firestore initialized successfully

---

## 🧪 Testing the Login Flow

### Step 1: Verify Backend is Running
```
✓ Check: http://localhost:8000/docs
✓ Should see: Swagger API documentation
```

### Step 2: Verify Frontend is Running
```
✓ Check: http://localhost:9100
✓ Should see: RaahAI login screen
```

### Step 3: Test Login API Directly
**Option A - Using Browser Console:**
```javascript
fetch('http://localhost:8000/api/v1/ngos/login', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    email: 'your@email.com',
    password: 'your_password'
  })
})
.then(r => r.json())
.then(d => console.log(d))
```

**Option B - Using cURL:**
```bash
curl -X POST http://localhost:8000/api/v1/ngos/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"your_password"}'
```

### Step 4: Check Browser Console for Errors
1. Open Chrome DevTools: `F12`
2. Go to **Console** tab
3. Go to **Network** tab
4. Try login and watch for:
   - CORS errors (red X)
   - 404 errors (endpoint not found)
   - 401 errors (invalid credentials)
   - Connection refused (backend down)

---

## 🔧 If Login Still Fails

### Check 1: Firebase Has NGO Data
```python
# In backend Python console:
from backend.services import firebase_service
firebase_service.initialize_firebase()
db = firebase_service.get_db()
ngos = db.collection('ngos').stream()
for ngo in ngos:
    print(ngo.to_dict())
```

### Check 2: Register First
If no NGO exists, you need to register:
1. Click "Register your NGO" on login screen
2. Fill in details
3. Should auto-login after registration
4. Then navigate to dashboard

### Check 3: Firestore Rules
Ensure Firestore security rules allow read/write:
```
allow read, write: if true;  // Dev only - change in production!
```

---

## 🚀 Running Commands (Updated)

### Terminal 1 - Backend
```bash
cd c:\Users\HIFZA\ HASHIM\RaahAI
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

### Terminal 2 - Frontend
```bash
cd c:\Users\HIFZA\ HASHIM\RaahAI\frontend\flutter_app
flutter run -d chrome
```

---

## 📝 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Connection failed" in app | Backend not running - check Terminal 1 |
| "Invalid credentials" error | NGO not registered or wrong password |
| Blank login screen | Frontend not loaded - check http://localhost:9100 |
| CORS error in console | Backend CORS not configured (should be fixed) |
| 404 on login endpoint | Wrong API URL in `api_constants.dart` |

---

## ✨ Success Indicators

When login works:
1. ✅ Submit credentials → 200 OK response
2. ✅ Credentials saved to secure storage
3. ✅ Fade transition to HomeShell (dashboard)
4. ✅ Dashboard loads with data
