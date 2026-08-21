import { useEffect, useState } from "react";
import { Link, useParams, useNavigate } from "react-router-dom";
import { getBook, getBookChapters, getChapter } from "../api";
import { isGuestUser, isChapterAllowedForGuest, GUEST_CHAPTER_LIMIT } from "../utils/guest";

export default function ChapterPage({ user }) {
  const { id, chapterId } = useParams();
  const navigate = useNavigate();
  const [book, setBook] = useState(null);
  const [chapter, setChapter] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [error, setError] = useState("");
  const guest = isGuestUser(user);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [b, listRes] = await Promise.all([getBook(id), getBookChapters(id)]);
        const items = listRes?.items || [];
        if (cancelled) return;
        setBook(b);
        setChapters(items);
        const idx = items.findIndex((c) => String(c.id) === String(chapterId));
        if (guest && idx >= 0 && !isChapterAllowedForGuest(idx)) {
          setError("guest-limit");
          return;
        }
        const ch = items.find((c) => String(c.id) === String(chapterId));
        if (!ch) {
          // fallback fetch
          try {
            const one = await getChapter(id, chapterId);
            if (!cancelled) setChapter(one);
          } catch (e) {
            if (!cancelled) setError(String(e.message || e));
          }
        } else if (!cancelled) {
          setChapter(ch);
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id, chapterId, guest]);

  if (error === "guest-limit") {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to keep reading</h3>
          <p>
            In guest mode you can read the first {GUEST_CHAPTER_LIMIT} chapters of each story.
            Create a free account to unlock the rest.
          </p>
          <Link className="btn btn-primary" to="/login">
            Sign in / Sign up
          </Link>
          <div style={{ marginTop: 12 }}>
            <Link to={`/stories/${id}`}>← Back to story</Link>
          </div>
        </div>
      </div>
    );
  }

  if (error) return <div className="container page error-banner">{error}</div>;
  if (!chapter) return <div className="container page">Loading chapter…</div>;

  const idx = chapters.findIndex((c) => String(c.id) === String(chapterId));
  const prev = idx > 0 ? chapters[idx - 1] : null;
  let next = idx >= 0 && idx < chapters.length - 1 ? chapters[idx + 1] : null;
  const nextLocked = guest && next && !isChapterAllowedForGuest(idx + 1);

  const paragraphs = String(chapter.content || "")
    .split(/\n\n+/)
    .map((p) => p.trim())
    .filter(Boolean);

  return (
    <div className="container reader-page">
      <div className="reader-top">
        <Link to={`/stories/${id}`} className="back-link">
          ← {book?.title || "Story"}
        </Link>
        <h1>{chapter.title || "Chapter"}</h1>
        {guest ? (
          <p className="meta">
            Guest mode · chapter {idx + 1} of {GUEST_CHAPTER_LIMIT} free
          </p>
        ) : null}
      </div>
      <article className="reader-body">
        {paragraphs.length ? (
          paragraphs.map((p, i) => <p key={i}>{p}</p>)
        ) : (
          <p className="meta">Empty chapter.</p>
        )}
      </article>
      {nextLocked ? (
        <div className="guest-lock">
          <h3>Unlock the rest of this story</h3>
          <p>Sign in to read chapter {idx + 2} and beyond.</p>
          <Link className="btn btn-primary" to="/login">
            Sign in
          </Link>
        </div>
      ) : null}
      <div className="reader-nav">
        {prev ? (
          <Link className="btn" to={`/stories/${id}/chapters/${prev.id}`}>
            ← Previous
          </Link>
        ) : (
          <span />
        )}
        {next && !nextLocked ? (
          <Link className="btn btn-primary" to={`/stories/${id}/chapters/${next.id}`}>
            Next →
          </Link>
        ) : (
          <Link className="btn" to={`/stories/${id}`}>
            Back to story
          </Link>
        )}
      </div>
    </div>
  );
}
