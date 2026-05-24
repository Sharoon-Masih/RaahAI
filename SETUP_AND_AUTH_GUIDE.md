# RaahAI Complete Setup & Authentication Guide

## ✓ Firebase Status: WORKING

Firebase and Firestore are properly initialized with your new credentials.

### Registered NGOs in Database:
1. **Test NGO 46b113cb** - test_ngo_46b113cb@example.com
2. **Saylani Welfare International Trust** - ops@saylani-demo.org
3. **Care Foundation** - care@example.com
4. **Edhi Foundation** - contact@edhi.org
5. **Test NGO 1b273379** - test_ngo_1b273379@example.com
6. **Test NGO de87bdd7** - test_ngo_de87bdd7@example.com

---

## Step 1: Kill All Running Servers

On Windows CMD/PowerShell, run:
```powershell
taskkill /F /IM python.exe 2>nul
taskkill /F /IM chrome.exe 2>nul
timeout /t 2
```

Or manually:
- Close all terminal windows with running servers
- Close Chrome browser

---

## Step 2: Start Backend Server (Terminal 1)

```bash
cd c:\Users\HIFZA\ HASHIM\RaahAI
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

**Wait for output:**
```
INFO:     Application startup complete.
```

---

## Step 3: Start Frontend Server (Terminal 2)

```bash
cd c:\Users\HIFZA\ HASHIM\RaahAI\frontend\flutter_app
flutter run -d chrome
```

**Wait for the Chrome window to open with the app**

---

## Step 4: Test Login with Existing NGO

**Use these credentials:**
- Email: `care@example.com`
- Password: (You'll need to know this - if you don't, see Step 5)

OR try:
- Email: `ops@saylani-demo.org`
- Password: (Same as above)

---

## Step 5: If Login Fails - Register New NGO First

On the login screen, click "Register your NGO" and fill in:
- **NGO Name:** Your NGO Name
- **Email:** your.ngo@example.com
- **Password:** Any password you want
- **Crisis Types:** Select 1-2 (e.g., "Earthquake", "Flood")
- **Locations:** Select 1-2 (e.g., "Karachi", "Lahore")

Then click **Register**

After successful registration, you'll auto-login and navigate to the dashboard.

---

## Step 6: Troubleshooting Checklist

If login still fails, check these in order:

### 1. Check Backend Logs
Look for errors in Terminal 1 (backend). Common issues:
- `[FAIL] Firebase query error` → Firebase issue (unlikely, already tested)
- `[WARN] No NGO found` → Email doesn't exist in database
- `[WARN] Password verification failed` → Wrong password

### 2. Check Frontend/Browser Console
In Chrome, press **F12** → **Console** tab:
- Look for red error messages
- Check if API calls are happening
- Look for CORS errors

### 3. Test Backend Directly

**Check if NGOs exist:**
```
http://localhost:8000/api/v1/ngos/debug/ngos-list
```

**Expected response:**
```json
{
  "count": 6,
  "ngos": [...]
}
```

### 4. Clear Browser Storage
In Chrome DevTools (F12):
- Go to **Application** tab
- Clear **Local Storage**
- Clear **Session Storage**
- Clear **Cookies**
- Refresh the page

### 5. Test a Fresh Registration

Try registering completely new NGO credentials instead of using existing ones.

---

## API Endpoints Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/ngos/register` | Register new NGO |
| POST | `/api/v1/ngos/login` | Login NGO |
| GET | `/api/v1/ngos/debug/ngos-list` | List all NGOs (debug) |
| GET | `/api/v1/firebase/cases` | Get cases (requires login) |

---

## Expected Flow

```
1. [Login Screen] → Enter credentials → Click "Sign In"
2. [Backend] → Validates email/password → Returns NGO data
3. [Frontend] → Receives response → Stores in secure storage
4. [Navigation] → Navigates to HomeShell (Dashboard)
5. [Dashboard] → Shows cases, stats, etc.
```

---

## What I Fixed

1. ✅ Added detailed error logging to backend login endpoint
2. ✅ Added debug endpoint to check NGO database
3. ✅ Verified Firebase credentials are valid
4. ✅ Verified Firestore collections exist
5. ✅ Confirmed password hashing works correctly

---

## Next: What You Need to Do

1. **Stop all servers**
2. **Restart them with commands above**
3. **Try logging in** with `care@example.com` (password: ask yourself what you set)
4. **Or register a new NGO** to test the full flow
5. **Monitor backend logs** for any error messages
6. **Check browser console** (F12) for client-side errors

If it still doesn't work after these steps, provide me with:
1. The exact error message from backend logs
2. The error message from browser console (F12)
3. The response from `/api/v1/ngos/debug/ngos-list`

