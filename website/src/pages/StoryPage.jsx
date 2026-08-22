import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  addToReadingList,
  followAuthor,
  getAuthorFollow,
  getBook,
  getBookChapters,
  getBookLike,
  getBookReviews,
  getToken,
  resolveAssetUrl,
  toggleBookLike,
  unfollowAuthor,
} from "../api";
import {
  GUEST_CHAPTER_LIMIT,
  isChapterAllowedForGuest,
  isGuestUser,
} from "../utils/guest";

export default function StoryPage({ user }) {
  const { id } = useParams();
  const navigate = useNavigate();
  const guest = isGuestUser(user);
  const [book, setBook] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [liked, setLiked] = useState(false);
  const [following, setFollowing] = useState(false);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [listOpen, setListOpen] = useState(false);
  const [chOpen, setChOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setError("");
      try {
        const [b, ch, rev] = await Promise.all([
          getBook(id),
          getBookChapters(id),
          getBookReviews(id).then((r) => r?.items || r || []).catch(() => []),
        ]);
        if (cancelled) return;
        setBook(b);
        setChapters(ch?.items || []);
        setReviews(Array.isArray(rev) ? rev : []);
        if (getToken() && !isGuestUser(user)) {
          try {
            const like = await getBookLike(id);
            if (!cancelled) setLiked(!!like?.liked || !!like?.is_liked);
          } catch {
            /* optional */
          }
          const authorId = b?.author_id || b?.user_id;
          if (authorId) {
            try {
              const f = await getAuthorFollow(authorId);
              if (!cancelled) setFollowing(!!f?.following);
            } catch {
              /* optional */
            }
          }
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id, user]);

  async function onLike() {
    if (!getToken() || guest) {
      setMsg("Sign in to like");
      return;
    }
    try {
      const res = await toggleBookLike(id, liked);
      const nowLiked = res?.liked === true || res?.is_liked === true || (res?.liked !== false && !liked);
      setLiked(nowLiked);
      setMsg(nowLiked ? "Liked" : "Unliked");
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function onFollow() {
    if (!getToken() || guest) {
      setMsg("Sign in to follow");
      return;
    }
    const authorId = book?.author_id || book?.user_id;
    if (!authorId) {
      setMsg("Author profile not linked");
      return;
    }
    try {
      if (following) {
        await unfollowAuthor(authorId);
        setFollowing(false);
        setMsg("Unfollowed");
      } else {
        await followAuthor(authorId);
        setFollowing(true);
        setMsg("Following");
      }
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function onAddList() {
    if (!getToken() || guest) {
      setMsg("Sign in to save");
      return;
    }
    try {
      await addToReadingList(Number(id));
      setMsg("Added to Currently Reading");
      setListOpen(false);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  if (error) return <div className="container page error-banner">{error}</div>;
  if (!book) return <div className="container page">Loading…</div>;

  const cover = resolveAssetUrl(book.cover_path || book.coverPath || "");
  const first = chapters[0];
  const tags = [book.genre, book.primary_genre, book.secondary_genre].filter(Boolean);
  const rating = book.rating != null ? Number(book.rating).toFixed(1) : "—";

  return (
    <div className="story-inkitt">
      <div
        className="story-hero"
        style={{
          backgroundImage: cover
            ? `linear-gradient(180deg, rgba(0,0,0,0.35), rgba(255,255,255,0.95) 70%), url(${cover})`
            : undefined,
        }}
      >
        <div className="story-hero-inner">
          {cover ? (
            <img className="story-hero-cover" src={cover} alt="" />
          ) : (
            <div
              className="story-hero-cover story-hero-cover--ph"
              style={{ background: book.accent_hex || "#1f2937" }}
            >
              {(book.title || "?")[0]}
            </div>
          )}
        </div>
      </div>

      <div className="story-inkitt-body">
        <aside className="story-left-rail">
          <button type="button" className={`story-action-btn ${liked ? "liked" : ""}`} onClick={onLike}>
            {liked ? "♥ Liked" : "♡ Like"}
          </button>
          <div className="list-dropdown-wrap">
            <button type="button" className="story-action-btn" onClick={() => setListOpen((v) => !v)}>
              🔖 Add to Reading List
            </button>
            {listOpen && (
              <div className="list-dropdown">
                <div className="list-dropdown-title">Private Lists</div>
                <button type="button" onClick={onAddList}>
                  Currently Reading
                </button>
                <button type="button" onClick={onAddList}>
                  Archived / Finished Books
                </button>
                <button type="button" className="list-create" onClick={onAddList}>
                  + Create New List
                </button>
              </div>
            )}
          </div>
          <Link className="story-action-btn story-action-primary" to={`/stories/${id}/review`}>
            Write a Review
          </Link>
          {msg ? <p className="meta side-msg">{msg}</p> : null}
          <div className="share-block meta">Share with your friends</div>
          <button type="button" className="story-action-btn muted">
            Report
          </button>
        </aside>

        <main className="story-center">
          <h1 className="story-title">{book.title}</h1>
          <div className="story-author-row">
            <div className="author-avatar">{(book.author || "A")[0]}</div>
            <div>
              <div className="author-name-line">
                <Link to={book.author_id ? `/authors/${book.author_id}` : "#"}>
                  {book.author || "Unknown"}
                </Link>
                <button type="button" className="btn-follow-sm" onClick={onFollow}>
                  {following ? "Following" : "Follow +"}
                </button>
              </div>
              <p className="meta">Author</p>
            </div>
          </div>
          <div className="tag-row">
            {tags.map((t) => (
              <span key={t} className="tag-chip">
                {t}
              </span>
            ))}
          </div>

          <h2 className="section-title">Summary</h2>
          <p className="summary-text">{book.description || "No summary yet."}</p>

          <div className="story-meta-grid">
            <div>
              <span className="meta-label">Genre</span>
              <strong className="meta-teal">{book.genre || book.primary_genre || "—"}</strong>
            </div>
            <div>
              <span className="meta-label">Status</span>
              <strong>{book.status_text || (book.is_completed ? "Complete" : "Ongoing")}</strong>
            </div>
            <div>
              <span className="meta-label">Rating</span>
              <strong className="meta-teal">
                ★ {rating} {reviews.length ? `${reviews.length} reviews` : ""}
              </strong>
            </div>
            <div>
              <span className="meta-label">Author</span>
              <strong className="meta-teal">{book.author || "—"}</strong>
            </div>
            <div>
              <span className="meta-label">Chapters</span>
              <strong>{chapters.length}</strong>
            </div>
            <div>
              <span className="meta-label">Age Rating</span>
              <strong>13+</strong>
            </div>
          </div>

          {first && (
            <div className="start-reading">
              <Link
                className="btn btn-primary"
                to={`/stories/${id}/chapters/${first.id}`}
              >
                Start reading — {first.title || "Chapter 1"}
              </Link>
            </div>
          )}

          <section className="reviews-block">
            <h2 className="section-title">Reviews ({reviews.length})</h2>
            <ul className="review-list">
              {reviews.slice(0, 8).map((r) => (
                <li key={r.id || r.created_at}>
                  <strong>
                    ★ {r.rating} · {r.display_name || r.username || "Reader"}
                  </strong>
                  <p>{r.comment || r.body || r.title || ""}</p>
                </li>
              ))}
              {!reviews.length && <li className="meta">No reviews yet. Be the first.</li>}
            </ul>
          </section>
        </main>

        <aside className="story-right-rail">
          <div className="chapters-panel">
            <button type="button" className="chapters-panel-head" onClick={() => setChOpen((v) => !v)}>
              <span>Chapters</span>
              <span className="meta">
                {chapters[0] ? `1 ${chapters[0].title || "Chapter 1"}` : "—"} ▾
              </span>
            </button>
            {chOpen && (
              <ul className="chapter-list chapter-list--panel">
                {chapters.map((c, i) => {
                  const locked = guest && !isChapterAllowedForGuest(i);
                  return (
                    <li key={c.id} className={locked ? "chapter-locked" : ""}>
                      {locked ? (
                        <span>
                          {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                          {c.title} 🔒
                        </span>
                      ) : (
                        <Link to={`/stories/${id}/chapters/${c.id}`}>
                          {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                          {c.title}
                        </Link>
                      )}
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}
