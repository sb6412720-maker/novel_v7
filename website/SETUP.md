# NovelHub Web (Inkitt-style) — Setup Guide

React + Vite website that uses the **same FastAPI backend and MySQL database** as the Flutter mobile app.

## 1. Prerequisites

- Node.js 18+
- Backend running (`uvicorn app.main:app --host 0.0.0.0 --port 8000`)
- Same `.env` / MySQL DB as mobile app

## 2. Install

```bash
cd website
npm install
```

## 3. Configure API URL

Create `website/.env`:

```
VITE_API_BASE_URL=http://127.0.0.1:8000
```

If the phone uses `http://192.168.1.2:8000`, the PC browser can use `http://127.0.0.1:8000` when backend is local.

## 4. Run

```bash
npm run dev
```

Open **http://localhost:5173**

## 5. What is included

| Route | Purpose |
|-------|---------|
| `/` | Inkitt-style home: hero, genre pills, trending shelves |
| `/discover` | Grid of all published stories (+ genre/search filters) |
| `/stories/:id` | Story detail (cover, summary, chapters, like, reading list) |
| `/stories/:id/chapters/:chapterId` | Chapter reader |
| `/library` | Ongoing / Completed / Reading list |
| `/write` | Your stories from mobile write API |
| `/login` | Email login or guest |

## 6. Backend CORS

If the browser blocks requests, allow the Vite origin in FastAPI:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 7. Next steps (optional)

- Google OAuth on web (same client ID + redirect URI)
- Full online chapter editor
- Dark mode toggle matching mobile
- SEO meta per story

## Brand

UI layout mirrors [Inkitt](https://www.inkitt.com/) (hero, soft genre pills, cover shelves, story detail). Product name remains **NovelHub**; data is yours via `/api/bootstrap` and related endpoints.
