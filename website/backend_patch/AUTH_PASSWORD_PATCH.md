# Secure email password (optional backend patch)

Your current `POST /api/auth/email` only uses `email` + `display_name` (no password check).

## What the website sends

```json
{ "email": "...", "display_name": "...", "password": "...", "username": "..." }
```

## Recommended backend changes (main.py)

1. Ensure column (startup):

```python
# MySQL
ALTER TABLE app_users ADD COLUMN password_hash VARCHAR(255) NULL;
# SQLite
# ALTER TABLE app_users ADD COLUMN password_hash TEXT;
```

2. Hash with werkzeug or hashlib+salt (prefer passlib/bcrypt in production):

```python
import hashlib, secrets

def _hash_password(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120000).hex()
    return f"{salt}${digest}"

def _verify_password(password: str, stored: str) -> bool:
    if not stored or "$" not in stored:
        return False
    salt, digest = stored.split("$", 1)
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120000).hex()
    return secrets.compare_digest(check, digest)
```

3. In `authenticate_email`:
   - If user exists and `password_hash` set → verify password or 401
   - If new user and password provided → store hash
   - If existing user without hash and password provided → set hash (migration)

## Google Sign-In

1. Google Cloud Console → create **OAuth 2.0 Web client ID**
2. Authorized JavaScript origins: `http://localhost:5173`
3. website `.env`:
   ```
   VITE_GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   VITE_API_BASE_URL=http://127.0.0.1:8000
   ```
4. backend `.env`:
   ```
   GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_IDS=your-web-client-id.apps.googleusercontent.com,your-android-client-id
   ```
5. You can reuse the **Web** client ID (not the Android one from `google-services.json`).  
   Add the Android client ID to `GOOGLE_CLIENT_IDS` so mobile keeps working.

`google-services.json` is for Android; the website needs a **Web** OAuth client ID.
