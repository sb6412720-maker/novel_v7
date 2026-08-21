# Backend password_hash + Google Web client

## 1. Apply password auth

Copy helpers + replace `EmailAuthRequest` and `authenticate_email` from `patched_auth_section.txt`
into `backend/app/main.py`.

Or replace your entire `backend/app/main.py` with the patched `main.py` in this folder
**only if** your local main matches GitHub main closely — otherwise merge the section by hand.

On next uvicorn start, `password_hash` column is added automatically.

### Behavior
- **New account**: password required (min 6 chars), stored as PBKDF2-SHA256 hash
- **Existing account with hash**: password must match
- **Existing email-only account (no hash)**: first successful login with a password sets the hash

## 2. Google Web client (your ID)

Client ID:
```
470949991659-avk11lvc5sv1ffietga62f8h591t7ijc.apps.googleusercontent.com
```

### Authorized JavaScript origins
```
http://localhost:5173
http://127.0.0.1:5173
```
If you open the site via LAN IP (e.g. phone testing web):
```
http://192.168.1.2:5173
```

### Authorized redirect URIs
For Google Identity Services **button** (id_token in browser), redirect URIs are often unused,
but Google console may still require at least one. Add:

```
http://localhost:5173
http://127.0.0.1:5173
```

(If the console insists on a path, use:)
```
http://localhost:5173/
http://127.0.0.1:5173/
```

You do **not** need the client secret for GIS one-tap / button id_token flow.

### website/.env
```
VITE_API_BASE_URL=http://127.0.0.1:8000
VITE_GOOGLE_CLIENT_ID=470949991659-avk11lvc5sv1ffietga62f8h591t7ijc.apps.googleusercontent.com
```

### backend/.env
```
GOOGLE_CLIENT_ID=470949991659-avk11lvc5sv1ffietga62f8h591t7ijc.apps.googleusercontent.com
GOOGLE_CLIENT_IDS=470949991659-avk11lvc5sv1ffietga62f8h591t7ijc.apps.googleusercontent.com,<ANDROID_CLIENT_ID_FROM_google-services.json>
```
