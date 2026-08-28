"""Facebook-style profile activity feed — only OTHER users' actions on this profile."""
from typing import Any, Callable


def register_activity_routes(
    app,
    *,
    fetch_all: Callable,
    LOGGER,
    helpers: dict,
) -> None:
    _row_get = helpers["row_get"]
    _normalize_cover_path = helpers["normalize_cover_path"]
    _ensure_book_likes_table = helpers["ensure_book_likes_table"]
    _ensure_chapter_comments_table = helpers["ensure_chapter_comments_table"]
    _ensure_author_follows_table = helpers["ensure_author_follows_table"]
    _ensure_wall_posts_table = helpers["ensure_wall_posts_table"]

    @app.get("/api/users/{user_id}/activity")
    def list_user_activity(user_id: int):
        """Activity directed AT this user: likes/comments/reviews on their books, follows, wall."""
        items: list[dict[str, Any]] = []

        def _actor(uid: Any) -> tuple[str, str]:
            name, photo = "Someone", ""
            if not uid:
                return name, photo
            try:
                urows = fetch_all(
                    "SELECT display_name, photo_url FROM app_users WHERE id=%s LIMIT 1",
                    (int(uid),),
                )
                if urows:
                    name = _row_get(urows[0], "display_name") or name
                    photo = _row_get(urows[0], "photo_url") or ""
            except Exception:
                pass
            return name, photo

        # Likes on this user's books (by others)
        try:
            _ensure_book_likes_table()
            likes = fetch_all(
                """
                SELECT bl.id, bl.user_id, bl.book_id, bl.created_at,
                       b.title, b.cover_path
                FROM book_likes bl
                JOIN books b ON b.id = bl.book_id
                WHERE b.user_id=%s AND bl.user_id != %s
                ORDER BY bl.id DESC
                LIMIT 40
                """,
                (user_id, user_id),
            )
            for row in likes or []:
                aname, aphoto = _actor(_row_get(row, "user_id"))
                title = _row_get(row, "title") or "your story"
                items.append({
                    "id": f"like-{_row_get(row, 'id')}",
                    "type": "like",
                    "title": f"{aname} liked {title}",
                    "message": f'{aname} liked your book "{title}"',
                    "actor_name": aname,
                    "actor_photo": aphoto,
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
                    "book_id": _row_get(row, "book_id"),
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity likes: %s", exc)

        # Comments on this user's chapters (by others)
        try:
            _ensure_chapter_comments_table()
            # chapters table uses story_id (not book_id)
            comments = fetch_all(
                """
                SELECT cc.id, cc.user_id, cc.chapter_id, cc.body, cc.created_at,
                       c.title AS chapter_title, c.story_id AS book_id,
                       b.title AS book_title, b.cover_path
                FROM chapter_comments cc
                JOIN chapters c ON c.id = cc.chapter_id
                JOIN books b ON b.id = c.story_id
                WHERE b.user_id=%s AND cc.user_id != %s
                ORDER BY cc.id DESC
                LIMIT 40
                """,
                (user_id, user_id),
            )
            for row in comments or []:
                aname, aphoto = _actor(_row_get(row, "user_id"))
                btitle = _row_get(row, "book_title") or "your story"
                body = (_row_get(row, "body") or "")[:120]
                items.append({
                    "id": f"comment-{_row_get(row, 'id')}",
                    "type": "comment",
                    "title": f"{aname} commented on {btitle}",
                    "message": body,
                    "actor_name": aname,
                    "actor_photo": aphoto,
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
                    "book_id": _row_get(row, "book_id"),
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity comments: %s", exc)

        # Reviews on this user's books (by others)
        try:
            reviews = fetch_all(
                """
                SELECT r.id, r.user_id, r.book_id, r.rating, r.comment AS body, r.created_at,
                       b.title, b.cover_path
                FROM book_reviews r
                JOIN books b ON b.id = r.book_id
                WHERE b.user_id=%s AND r.user_id != %s
                ORDER BY r.id DESC
                LIMIT 30
                """,
                (user_id, user_id),
            )
            for row in reviews or []:
                aname, aphoto = _actor(_row_get(row, "user_id"))
                title = _row_get(row, "title") or "your story"
                try:
                    rating = int(_row_get(row, "rating") or 0)
                except Exception:
                    rating = 0
                body = (_row_get(row, "body") or "")[:120]
                stars = ("★" * rating) if rating > 0 else ""
                items.append({
                    "id": f"review-{_row_get(row, 'id')}",
                    "type": "review",
                    "title": f"{aname} reviewed {title}",
                    "message": f"{stars} {body}".strip(),
                    "actor_name": aname,
                    "actor_photo": aphoto,
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
                    "book_id": _row_get(row, "book_id"),
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity reviews: %s", exc)

        # Follows
        try:
            _ensure_author_follows_table()
            # author_follows schema: user_id (follower) + author_id
            follows = fetch_all(
                """
                SELECT id, user_id AS follower_id, created_at
                FROM author_follows
                WHERE author_id=%s AND user_id != %s
                ORDER BY id DESC
                LIMIT 40
                """,
                (user_id, user_id),
            )
            for row in follows or []:
                fid = _row_get(row, "follower_id") or _row_get(row, "user_id")
                aname, aphoto = _actor(fid)
                items.append({
                    "id": f"follow-{_row_get(row, 'id')}",
                    "type": "follow",
                    "title": f"{aname} started following you",
                    "message": f"{aname} is now following you",
                    "actor_name": aname,
                    "actor_photo": aphoto,
                    "actor_user_id": fid,
                    "cover_path": "",
                    "book_id": None,
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity follows: %s", exc)

        # Wall posts on this profile
        try:
            _ensure_wall_posts_table()
            wall = fetch_all(
                """
                SELECT id, user_id, body, image_path, created_at
                FROM wall_posts
                WHERE target_user_id=%s
                ORDER BY id DESC
                LIMIT 30
                """,
                (user_id,),
            )
            for row in wall or []:
                aname, aphoto = _actor(_row_get(row, "user_id"))
                body = (_row_get(row, "body") or "")[:160]
                items.append({
                    "id": f"wall-{_row_get(row, 'id')}",
                    "type": "wall",
                    "title": f"{aname} posted on your wall",
                    "message": body,
                    "actor_name": aname,
                    "actor_photo": aphoto,
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "image_path") or ""),
                    "book_id": None,
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity wall: %s", exc)

        items.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
        return {"items": items[:60]}
