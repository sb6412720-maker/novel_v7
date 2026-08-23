"""
Incremental content enrichment for production:
- Sample chapters for books that have none
- Sample wall posts for authors
- Sample book reviews
Bounded work so Vercel cold starts stay under timeout.
"""
from __future__ import annotations

import logging
from typing import Any, Callable

LOGGER = logging.getLogger("novel_app.content_seed")

SAMPLE_CHAPTER_BODIES = [
    (
        "The morning light slipped through the curtains as {hero} woke to a world "
        "that no longer felt familiar. Every choice from the night before echoed "
        "in the quiet of the room, and the path ahead was anything but clear."
    ),
    (
        "By noon, secrets had already begun to surface. A message left unread, "
        "a door left open, and a promise that could not be kept. {hero} knew "
        "there would be no turning back once the truth came out."
    ),
    (
        "Night fell harder than expected. In the space between fear and hope, "
        "{hero} made a decision that would reshape everything—and everyone—involved."
    ),
]


def _db() -> tuple[Callable, Callable]:
    """Resolve fetch_all / execute_write from main (they live there, not db_runtime)."""
    try:
        from . import main as main_mod
    except Exception:
        import app.main as main_mod  # type: ignore
    return main_mod.fetch_all, main_mod.execute_write


def seed_chapters_for_empty_books(limit_books: int = 12, chapters_per_book: int = 3) -> dict[str, Any]:
    report: dict[str, Any] = {"books_touched": 0, "chapters_added": 0, "errors": 0}
    try:
        fetch_all, execute_write = _db()
        books = fetch_all(
            """
            SELECT b.id, b.title, b.author
            FROM books b
            WHERE LOWER(COALESCE(b.status_text, 'published')) NOT IN ('draft', 'unpublished', 'private')
              AND NOT EXISTS (SELECT 1 FROM chapters c WHERE c.story_id = b.id)
            ORDER BY b.id DESC
            LIMIT %s
            """,
            (limit_books,),
        )
    except Exception as exc:
        LOGGER.warning("seed chapters query failed: %s", exc)
        report["error"] = str(exc)
        return report

    for book in books or []:
        bid = book.get("id") if isinstance(book, dict) else book[0]
        title = (book.get("title") if isinstance(book, dict) else "") or "the story"
        author = (book.get("author") if isinstance(book, dict) else "") or "the protagonist"
        hero = str(author).split()[0] if author else "they"
        try:
            for n in range(1, chapters_per_book + 1):
                body_tpl = SAMPLE_CHAPTER_BODIES[(n - 1) % len(SAMPLE_CHAPTER_BODIES)]
                body = body_tpl.format(hero=hero)
                body = (
                    f"{body}\n\n"
                    f"Chapter {n} of \"{title}\" continues as the stakes rise. "
                    f"Every conversation carries weight, and the smallest detail may decide the ending.\n\n"
                    f"Readers who stay with this chapter will see why {hero} cannot walk away."
                )
                execute_write(
                    """
                    INSERT INTO chapters (story_id, chapter_number, title, content, sort_order)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (bid, n, f"Chapter {n}", body, n),
                )
                report["chapters_added"] += 1
            report["books_touched"] += 1
        except Exception as exc:
            report["errors"] += 1
            LOGGER.warning("seed chapters for book %s failed: %s", bid, exc)
    return report


def _ensure_seed_users() -> list[int]:
    ids: list[int] = []
    try:
        fetch_all, execute_write = _db()
        rows = fetch_all("SELECT id FROM app_users ORDER BY id ASC LIMIT 8")
        for r in rows or []:
            ids.append(int(r["id"] if isinstance(r, dict) else r[0]))
    except Exception as exc:
        LOGGER.warning("list users for seed: %s", exc)

    if len(ids) >= 2:
        return ids

    seed_people = [
        ("reader_one@seed.local", "Reader One"),
        ("reader_two@seed.local", "Reader Two"),
        ("fan_three@seed.local", "Story Fan"),
    ]
    try:
        fetch_all, execute_write = _db()
    except Exception:
        return ids

    for email, name in seed_people:
        try:
            uid, _ = execute_write(
                """
                INSERT INTO app_users (email, display_name, auth_provider)
                VALUES (%s, %s, 'seed')
                """,
                (email, name),
            )
            if uid:
                ids.append(int(uid))
            else:
                rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
                if rows:
                    ids.append(int(rows[0]["id"] if isinstance(rows[0], dict) else rows[0][0]))
        except Exception:
            try:
                rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
                if rows:
                    ids.append(int(rows[0]["id"] if isinstance(rows[0], dict) else rows[0][0]))
            except Exception:
                pass
    return ids


def seed_wall_posts(limit_authors: int = 8) -> dict[str, Any]:
    report: dict[str, Any] = {"posts_added": 0, "errors": 0}
    try:
        fetch_all, execute_write = _db()
        try:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS wall_posts (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    target_user_id INT NOT NULL,
                    body TEXT NOT NULL,
                    image_path VARCHAR(512) DEFAULT '',
                    likes_count INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """,
                (),
            )
        except Exception:
            pass

        authors = fetch_all(
            """
            SELECT DISTINCT user_id AS id FROM books
            WHERE user_id IS NOT NULL AND user_id > 0
            ORDER BY user_id DESC
            LIMIT %s
            """,
            (limit_authors,),
        )
    except Exception as exc:
        report["error"] = str(exc)
        return report

    samples = [
        "New chapter is live — thank you for reading along!",
        "Working on the next twist. Any guesses?",
        "Happy weekend, readers. Drop a comment if you are caught up!",
        "Cover refresh coming soon. Stay tuned.",
    ]
    for a in authors or []:
        uid = int(a["id"] if isinstance(a, dict) else a[0])
        try:
            existing = fetch_all(
                "SELECT COUNT(*) AS c FROM wall_posts WHERE target_user_id=%s",
                (uid,),
            )
            count = 0
            if existing:
                row0 = existing[0]
                count = int(row0["c"] if isinstance(row0, dict) else row0[0])
            if count >= 2:
                continue
            for body in samples[:2]:
                execute_write(
                    """
                    INSERT INTO wall_posts (user_id, target_user_id, body, image_path, likes_count)
                    VALUES (%s, %s, %s, '', 0)
                    """,
                    (uid, uid, body),
                )
                report["posts_added"] += 1
        except Exception as exc:
            report["errors"] += 1
            LOGGER.warning("wall seed for user %s: %s", uid, exc)
    return report


def seed_sample_reviews(limit_books: int = 12) -> dict[str, Any]:
    report: dict[str, Any] = {"reviews_added": 0, "errors": 0}
    user_ids = _ensure_seed_users()
    if not user_ids:
        report["error"] = "no users for reviews"
        return report
    try:
        fetch_all, execute_write = _db()
        books = fetch_all(
            """
            SELECT id, title FROM books
            WHERE LOWER(COALESCE(status_text, 'published')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY id DESC
            LIMIT %s
            """,
            (limit_books,),
        )
    except Exception as exc:
        report["error"] = str(exc)
        return report

    comments = [
        "Could not put this down. Great pacing!",
        "Loved the characters and the emotional arc.",
        "Solid plot with a few surprises. Recommend.",
        "Beautifully written. Waiting for the next chapter.",
    ]
    for i, book in enumerate(books or []):
        bid = int(book["id"] if isinstance(book, dict) else book[0])
        uid = user_ids[i % len(user_ids)]
        try:
            existing = fetch_all(
                "SELECT id FROM book_reviews WHERE book_id=%s AND user_id=%s LIMIT 1",
                (bid, uid),
            )
            if existing:
                continue
            rating = 4 + (i % 2)
            comment = comments[i % len(comments)]
            execute_write(
                """
                INSERT INTO book_reviews (book_id, user_id, rating, comment)
                VALUES (%s, %s, %s, %s)
                """,
                (bid, uid, rating, comment),
            )
            report["reviews_added"] += 1
        except Exception as exc:
            report["errors"] += 1
            LOGGER.warning("review seed book %s: %s", bid, exc)
    return report


def run_content_enrichment(force: bool = False) -> dict[str, Any]:
    result: dict[str, Any] = {"ran": False}
    try:
        fetch_all, _ = _db()
        rows = fetch_all("SELECT COUNT(*) AS c FROM chapters")
        chapter_count = int(rows[0]["c"] if isinstance(rows[0], dict) else rows[0][0]) if rows else 0
    except Exception as exc:
        chapter_count = 0
        result["chapter_count_error"] = str(exc)

    if force or chapter_count < 30:
        result["chapters"] = seed_chapters_for_empty_books(limit_books=12, chapters_per_book=3)
    else:
        result["chapters"] = {"skipped": True, "reason": "enough_chapters", "count": chapter_count}

    try:
        result["wall"] = seed_wall_posts(limit_authors=8)
    except Exception as exc:
        result["wall"] = {"error": str(exc)}

    try:
        result["reviews"] = seed_sample_reviews(limit_books=12)
    except Exception as exc:
        result["reviews"] = {"error": str(exc)}

    result["ran"] = True
    LOGGER.info("content enrichment: %s", result)
    return result
