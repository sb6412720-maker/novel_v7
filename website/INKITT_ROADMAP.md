# NovelHub web — Inkitt clone roadmap

## Architecture (one database)

```
MySQL  ←── FastAPI (backend)
              ↑
     ┌────────┼────────┐
 Flutter    Website   Admin panel
 (mobile)   (React)   (Vite React)
```

All three use the same `API_BASE_URL` / backend. Seed/migrations run on FastAPI startup.

## Done

- Home (hero, genre pills, single phone image, trending grid, reading lists, shelves)
- Full-width header matching Inkitt nav labels
- Free Books / Discover (search, status, genre filters)
- Genre pages `/genres/:genre`
- Story 3-column + guest **2-chapter** limit
- Chapter reader with guest lock
- Write / writers hub + my stories from API
- Community, Contests, Author profile routes
- Library (ongoing / completed / reading list)
- Login + guest token

## Next (priority order)

1. **Story create/edit on web** — POST `/api/write/stories` + chapters (parity with mobile Write)
2. **Reviews UI** on story page — GET/POST `/api/books/{id}/reviews`
3. **Follow author** — `/api/authors/{id}/follow`
4. **Community wall** — wire chat/activity endpoints if present
5. **Contests table** in admin + real entries
6. **Pixel polish** — exact fonts, footer columns, more shelves from bootstrap sections
7. **Deploy** — same CORS, production `VITE_API_BASE_URL`

## Local run

```bash
# Terminal 1 — backend (MySQL)
cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2 — website
cd website
echo VITE_API_BASE_URL=http://127.0.0.1:8000 > .env
npm run dev
```

Flutter: `--dart-define=API_BASE_URL=http://192.168.x.x:8000`  
Admin: point API base to same host.
