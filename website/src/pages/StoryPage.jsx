import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { isGuestUser, isChapterAllowedForGuest, GUEST_CHAPTER_LIMIT } from "../utils/guest";
import {
  addToReadingList,
  getBook,
  getBookChapters,
  getBookLike,
  likeBook,
  unlikeBook,
  resolveAssetUrl,
  getToken,
} from "../api";

export default function StoryPage({ user }) {
  const guest = isGuestUser(user);
  const { id } = useParams();
  const [book, setBook] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [liked, setLiked] = useState(false);
  const [chaptersOpen, setChaptersOpen] = useState(true);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError("");
      try {
        const [b, ch] = await Promise.all([
          getBook(id),
          getBookChapters(id).then((r) => r?.items || []).catch(() => []),
        ]);
        if (!cancelled) {
          setBook(b);
          setChapters(Array.isArray(ch) ? ch : []);
        }
        if (getToken()) {
          try {
            const like = await getBookLike(id);
            if (!cancelled) setLiked(!!(like?.liked || like?.is_liked));
          } catch {
            /* ignore */
          }
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id]);

  async function onLike() {
    if (!getToken()) {
      setMsg("Sign in to like stories");
      return;
    }
    try {
      if (liked) {
        await unlikeBook(id);
        setLiked(false);
        setMsg("Removed like");
      } else {
        await likeBook(id);
        setLiked(true);
        setMsg("Liked");
      }
    } catch (e) {
      setMsg(e.status === 401 ? "Sign in to like stories" : String(e.message || e));
    }
  }

  async function onSave() {
    if (!getToken()) {
      setMsg("Sign in to save to reading list");
      return;
    }
    try {
      await addToReadingList(Number(id));
      setMsg("Saved to reading list");
    } catch (e) {
      setMsg(e.status === 401 ? "Sign in to save" : String(e.message || e));
    }
  }

  if (loading) return <div className="container page">Loading story…</div>;
  if (error) return <div className="container page error-banner">{error}</div>;
  if (!book) return null;

  const cover = resolveAssetUrl(book.cover_path || book.coverPath || "");
  const firstChapter = chapters[0];
  const tags = [book.genre, book.status_text].filter(Boolean);
  const authorInitial = (book.author || "?").slice(0, 1).toUpperCase();

  return (
    <div className="story-page">
      {/* Banner with centered cover — Inkitt style */}
      <div className="story-banner">
        <div
          className="story-banner-blur"
          style={
            cover
              ? { backgroundImage: `url(${cover})` }
              : { background: book.accent_hex || "#1f2937" }
          }
        />
        <div className="story-banner-cover">
          {cover ? (
            <img src={cover} alt="" />
          ) : (
            <div
              className="book-cover--fallback tall"
              style={{ background: book.accent_hex || "#1f2937", display: "grid" }}
            >
              <span className="fallback-letter">{(book.title || "?")[0]}</span>
            </div>
          )}
        </div>
      </div>

      {/* 3-column body: actions | main | chapters */}
      <div className="container story-three">
        {/* LEFT — actions */}
        <aside className="story-col-actions">
          <button
            type="button"
            className={`story-action-btn ${liked ? "is-liked" : ""}`}
            onClick={onLike}
          >
            {liked ? "♥ Liked" : "♡ Like"}
          </button>
          <button type="button" className="story-action-btn" onClick={onSave}>
            🔖 Add to Reading List
          </button>
          {firstChapter ? (
            <Link
              className="story-action-btn story-action-primary"
              to={`/stories/${id}/chapters/${firstChapter.id}`}
            >
              Start reading
            </Link>
          ) : (
            <button type="button" className="story-action-btn story-action-primary" disabled>
              No chapters yet
            </button>
          )}
          <p className="share-label">Share with your friends</p>
          <div className="share-row">
            <button type="button" className="share-ico" title="Share" onClick={() => {
              if (navigator.share) navigator.share({ title: book.title, url: window.location.href });
              else { navigator.clipboard?.writeText(window.location.href); setMsg("Link copied"); }
            }}>
              ↗
            </button>
          </div>
          {msg ? <p className="meta side-msg">{msg}</p> : null}
        </aside>

        {/* CENTER — title, author, summary */}
        <div className="story-col-main">
          <h1 className="story-title">{book.title}</h1>
          <div className="story-author-row">
            <div className="author-avatar" aria-hidden>
              {authorInitial}
            </div>
            <div>
              <div className="author-name-lg">
                {book.user_id ? (
                  <Link to={`/authors/${book.user_id}`}>{book.author || "Unknown"}</Link>
                ) : (
                  book.author || "Unknown"
                )}
              </div>
              {book.rating ? (
                <div className="author-sub">★ {Number(book.rating).toFixed(1)}</div>
              ) : null}
            </div>
          </div>
          {tags.length > 0 && (
            <div className="tag-row">
              {tags.map((t) => (
                <span key={t} className="tag">
                  {t}
                </span>
              ))}
            </div>
          )}
          <h2 className="section-title">Summary</h2>
          <p className="story-summary">{book.description || "No summary yet."}</p>
        </div>

        {/* RIGHT — chapters panel */}
        <aside className="story-col-chapters">
          <button
            type="button"
            className="chapters-toggle"
            onClick={() => setChaptersOpen((v) => !v)}
            aria-expanded={chaptersOpen}
          >
            <span>
              <strong>Chapters</strong>
              <span className="chapters-count">
                {chapters.length
                  ? ` ${chapters[0]?.chapter_number != null ? chapters[0].chapter_number : 1}. ${chapters[0]?.title || "Chapter 1"}`
                  : " None yet"}
              </span>
            </span>
            <span className="chev">{chaptersOpen ? "▴" : "▾"}</span>
          </button>
          {chaptersOpen && (
            <>
              <ul className="chapter-list chapter-list--panel">
                {chapters.map((c, i) => {
                  const locked = guest && !isChapterAllowedForGuest(i);
                  return (
                    <li key={c.id || i} className={locked ? "chapter-locked" : ""}>
                      {locked ? (
                        <span>
                          {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                          {c.title || `Chapter ${i + 1}`}
                        </span>
                      ) : (
                        <Link to={`/stories/${id}/chapters/${c.id}`}>
                          {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                          {c.title || `Chapter ${i + 1}`}
                        </Link>
                      )}
                    </li>
                  );
                })}
                {chapters.length === 0 && <li className="meta">No chapters published.</li>}
              </ul>
              {guest && chapters.length > GUEST_CHAPTER_LIMIT ? (
                <div className="guest-lock" style={{ marginTop: 12, padding: 16 }}>
                  <h3 style={{ fontSize: "1rem", margin: "0 0 6px" }}>Guest limit</h3>
                  <p style={{ margin: "0 0 10px", fontSize: "0.85rem" }}>
                    Guests can read the first {GUEST_CHAPTER_LIMIT} chapters. Sign in for the full
                    story.
                  </p>
                  <Link className="btn btn-primary btn-sm" to="/login">
                    Sign in
                  </Link>
                </div>
              ) : null}
            </>
          )}
        </aside>
      </div>
    </div>
  );
}
