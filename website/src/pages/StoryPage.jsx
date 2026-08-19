import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
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

export default function StoryPage() {
  const { id } = useParams();
  const [book, setBook] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [liked, setLiked] = useState(false);
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

  return (
    <div className="story-page">
      <div
        className="story-hero-bg"
        style={
          cover
            ? { backgroundImage: `url(${cover})` }
            : { background: book.accent_hex || "#1f2937" }
        }
      />
      <div className="container story-layout">
        <aside className="story-side">
          <div className="story-cover-lg">
            {cover ? (
              <img src={cover} alt="" />
            ) : (
              <div className="book-cover--fallback tall">{(book.title || "?")[0]}</div>
            )}
          </div>
          <button type="button" className={`btn btn-block ${liked ? "btn-liked" : ""}`} onClick={onLike}>
            {liked ? "♥ Liked" : "♡ Like"}
          </button>
          <button type="button" className="btn btn-block" onClick={onSave}>
            🔖 Add to Reading List
          </button>
          {firstChapter ? (
            <Link className="btn btn-primary btn-block" to={`/stories/${id}/chapters/${firstChapter.id}`}>
              Start reading
            </Link>
          ) : (
            <button type="button" className="btn btn-primary btn-block" disabled>
              No chapters yet
            </button>
          )}
          {msg ? <p className="meta side-msg">{msg}</p> : null}
        </aside>

        <div className="story-main">
          <h1 className="story-title">{book.title}</h1>
          <p className="story-author">
            by <strong>{book.author || "Unknown"}</strong>
            {book.rating ? (
              <span className="rating-inline"> · ★ {Number(book.rating).toFixed(1)}</span>
            ) : null}
          </p>
          {(book.genre || book.status_text) && (
            <div className="tag-row">
              {book.genre ? <span className="tag">{book.genre}</span> : null}
              {book.status_text ? <span className="tag">{book.status_text}</span> : null}
            </div>
          )}
          <h2 className="section-title">Summary</h2>
          <p className="story-summary">{book.description || "No summary yet."}</p>

          <h2 className="section-title">Chapters ({chapters.length})</h2>
          <ul className="chapter-list">
            {chapters.map((c, i) => (
              <li key={c.id || i}>
                <Link to={`/stories/${id}/chapters/${c.id}`}>
                  {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                  {c.title || `Chapter ${i + 1}`}
                </Link>
              </li>
            ))}
            {chapters.length === 0 && <li className="meta">No chapters published.</li>}
          </ul>
        </div>
      </div>
    </div>
  );
}
