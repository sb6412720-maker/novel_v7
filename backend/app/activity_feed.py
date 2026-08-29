"""Profile activity feed — others\' actions on this user\'s books/profile (fast, no N+1)."""
from __future__ import annotations

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

    @app.get("/api/users/{user_id}/activity")
    def list_user_activity(user_id: int):
        """Likes, comments, reviews, follows, wall posts directed at this user."""
        items: list[dict[str, Any]] = []
        uid = int(user_id)

        # Likes on this user\'s books
        try:
            likes = fetch_all(
                """
                SELECT bl.id, bl.user_id, bl.book_id, bl.created_at,
                       b.title, b.cover_path,
                       COALESCE(u.display_name, \'Someone\') AS actor_name,
                       COALESCE(u.photo_url, \'\') AS actor_photo
                FROM book_likes bl
                JOIN books b ON b.id = bl.book_id
                LEFT JOIN app_users u ON u.id = bl.user_id
                WHERE b.user_id=%s AND bl.user_id != %s
                ORDER BY bl.id DESC
                LIMIT 25
                """,
                (uid, uid),
            )
            for row in likes or []:
                aname = _row_get(row, "actor_name") or "Someone"
                title = _row_get(row, "title") or "your story"
                items.append({
                    "id": f"like-{_row_get(row, \'id\')}",
                    "type": "like",
                    "title": f"{aname} liked {title}",
                    "message": f\'{aname} liked your book "{title}"\',
                    "actor_name": aname,
                    "actor_photo": _row_get(row, "actor_photo") or "",
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
                    "book_id": _row_get(row, "book_id"),
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity likes: %s", exc)

        # Comments on this user\'s chapters
        try:
            comments = fetch_all(
                """
                SELECT cc.id, cc.user_id, cc.body, cc.created_at,
                       c.story_id AS book_id, b.title AS book_title, b.cover_path,
                       COALESCE(u.display_name, \'Someone\') AS actor_name,
                       COALESCE(u.photo_url, \'\') AS actor_photo
                FROM chapter_comments cc
                JOIN chapters c ON c.id = cc.chapter_id
                JOIN books b ON b.id = c.story_id
                LEFT JOIN app_users u ON u.id = cc.user_id
                WHERE b.user_id=%s AND cc.user_id != %s
                ORDER BY cc.id DESC
                LIMIT 25
                """,
                (uid, uid),
            )
            for row in comments or []:
                aname = _row_get(row, "actor_name") or "Someone"
                btitle = _row_get(row, "book_title") or "your story"
                body = (_row_get(row, "body") or "")[:120]
                items.append({
                    "id": f"comment-{_row_get(row, \'id\')}",
                    "type": "comment",
                    "title": f"{aname} commented on {btitle}",
                    "message": body or f"New comment on {btitle}",
                    "actor_name": aname,
                    "actor_photo": _row_get(row, "actor_photo") or "",
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
                    "book_id": _row_get(row, "book_id"),
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity comments: %s", exc)

        # Reviews on this user\'s books
        try:
            reviews = fetch_all(
                """
                SELECT r.id, r.user_id, r.book_id, r.rating, r.comment AS body, r.created_at,
                       b.title, b.cover_path,
                       COALESCE(u.display_name, \'Someone\') AS actor_name,
                       COALESCE(u.photo_url, \'\') AS actor_photo
                FROM book_reviews r
                JOIN books b ON b.id = r.book_id
                LEFT JOIN app_users u ON u.id = r.user_id
                WHERE b.user_id=%s AND r.user_id != %s
                ORDER BY r.id DESC
                LIMIT 25
                """,
                (uid, uid),
            )
            for row in reviews or []:
                aname = _row_get(row, "actor_name") or "Someone"
                title = _row_get(row, "title") or "your story"
                body = (_row_get(row, "body") or "")[:120]
                rating = _row_get(row, "rating") or ""
                items.append({
                    "id": f"review-{_row_get(row, \'id\')}",
                    "type": "review",
                    "title": f"{aname} reviewed {title}",
                    "message": body or f"Rated {rating}/5",
                    "actor_name": aname,
                    "actor_photo": _row_get(row, "actor_photo") or "",
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
                    "book_id": _row_get(row, "book_id"),
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity reviews: %s", exc)

        # Follows
        try:
            follows = fetch_all(
                """
                SELECT f.id, f.user_id AS follower_id, f.created_at,
                       COALESCE(u.display_name, \'Someone\') AS actor_name,
                       COALESCE(u.photo_url, \'\') AS actor_photo
                FROM author_follows f
                LEFT JOIN app_users u ON u.id = f.user_id
                WHERE f.author_id=%s AND f.user_id != %s
                ORDER BY f.id DESC
                LIMIT 25
                """,
                (uid, uid),
            )
            for row in follows or []:
                aname = _row_get(row, "actor_name") or "Someone"
                fid = _row_get(row, "follower_id")
                items.append({
                    "id": f"follow-{_row_get(row, \'id\')}",
                    "type": "follow",
                    "title": f"{aname} started following you",
                    "message": f"{aname} is now following you",
                    "actor_name": aname,
                    "actor_photo": _row_get(row, "actor_photo") or "",
                    "actor_user_id": fid,
                    "cover_path": "",
                    "book_id": None,
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity follows: %s", exc)

        # Wall posts
        try:
            wall = fetch_all(
                """
                SELECT w.id, w.user_id, w.body, w.image_path, w.created_at,
                       COALESCE(u.display_name, \'Someone\') AS actor_name,
                       COALESCE(u.photo_url, \'\') AS actor_photo
                FROM wall_posts w
                LEFT JOIN app_users u ON u.id = w.user_id
                WHERE w.target_user_id=%s AND w.user_id != %s
                ORDER BY w.id DESC
                LIMIT 20
                """,
                (uid, uid),
            )
            for row in wall or []:
                aname = _row_get(row, "actor_name") or "Someone"
                body = (_row_get(row, "body") or "")[:160]
                items.append({
                    "id": f"wall-{_row_get(row, \'id\')}",
                    "type": "wall",
                    "title": f"{aname} posted on your wall",
                    "message": body or "New wall post",
                    "actor_name": aname,
                    "actor_photo": _row_get(row, "actor_photo") or "",
                    "actor_user_id": _row_get(row, "user_id"),
                    "cover_path": _normalize_cover_path(_row_get(row, "image_path") or ""),
                    "book_id": None,
                    "created_at": str(_row_get(row, "created_at") or ""),
                })
        except Exception as exc:
            LOGGER.warning("activity wall: %s", exc)

        items.sort(key=lambda x: str(x.get("created_at") or x.get("id") or ""), reverse=True)
        return {"items": items[:60]}
