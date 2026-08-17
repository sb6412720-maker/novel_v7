# Local fixes (Google Not Found + empty Discover)

## What changed

1. **`lib/data/services/api_service.dart`**
   - In **debug**, the app **no longer falls back** to the Hugging Face production URL when local requests fail.
   - That fallback was the main reason **Sign in with Google** showed **"Not Found"** and **Guest Discover** looked empty (the HF Space returns 404 for `/api/auth/google` and has no seed data).

2. Production HF Space (`https://lakmasachith-novel-app-backend.hf.space`) is still outdated. Use a **local backend** until you redeploy.

## How to run after pull

### Backend

```bash
cd backend
cp .env.local .env
# Set MYSQL_PASSWORD to your real password (or leave empty only if root has no password)
# MYSQL_DATABASE=novel_app_db_v2
# MYSQL_FALLBACK_SQLITE=true is recommended so empty MySQL still seeds SQLite

pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Verify:

```bash
curl http://127.0.0.1:8000/api/health
# Expect books > 0, chapters > 0

curl -X POST http://127.0.0.1:8000/api/auth/google -H "Content-Type: application/json" -d '{}'
# Should be 400 (missing token), NOT 404
```

### Flutter

**Emulator:**

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**Physical device (same Wi‑Fi as PC):**

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000
```

Optional Google server client id:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=GOOGLE_CLIENT_ID=470949991659-avk11lvc5sv1ffietga62f8h591t7ijc.apps.googleusercontent.com
```

## Guest access

- Discover / read are public via `/api/bootstrap` and book endpoints.
- Guest login creates a per-device guest user and JWT.
- Write actions still require a valid user token (guest has one). To hard-block guest writes later, gate write routes on `provider != 'guest'`.
