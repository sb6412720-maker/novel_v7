import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  addToReadingList,
  getBook,
  getBookChapters,
  getChapterComments,
  getChapterReactions,
  getToken,
  postChapterComment,
  toggleChapterReaction,
} from "../api";
import {
  GUEST_CHAPTER_LIMIT,
  isChapterAllowedForGuest,
  isGuestUser,
} from "../utils/guest";

const REACTIONS = [
  { label: "Love this", emoji: "❤️" },
  { label: "Funny", emoji: "😂" },
  { label: "Spicy", emoji: "🌶️" },
  { label: "Suspenseful", emoji: "😮" },
  { label: "Emotional", emoji: "📚" },
  { label: "Profound", emoji: "🤯" },
  { label: "Heartwarming", emoji: "🥰" },
  { label: "Shocking", emoji: "😱" },
  { label: "Good Writing", emoji: "✍️" },
  { label: "Compelling Plot", emoji: "🎢" },
  { label: "Great Character", emoji: "😎" },
  { label: "Strong Dialog", emoji: "💬" },
];

export default function ChapterPage({ user }) {
  const { id, chapterId } = useParams();
  const guest = isGuestUser(user);
  const [book, setBook] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [chapter, setChapter] = useState(null);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [comments, setComments] = useState([]);
  const [paraCounts, setParaCounts] = useState({});
  const [activePara, setActivePara] = useState(null);
  const [panelOpen, setPanelOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [reactionCounts, setReactionCounts] = useState({});
  const [mine, setMine] = useState([]);

  const chapterNumber = useMemo(() => {
    if (!chapter) return 1;
    return Number(chapter.chapter_number) || 1;
  }, [chapter]);

  async function loadComments(num) {
    try {
      const res = await getChapterComments(id, num);
      setComments(res?.items || []);
      setParaCounts(res?.paragraph_counts || {});
    } catch {
      setComments([]);
      setParaCounts({});
    }
  }

  async function loadReactions(num) {
    try {
      const res = await getChapterReactions(id, num);
      setReactionCounts(res?.counts || res || {});
      setMine(res?.mine || []);
    } catch {
      setReactionCounts({});
      setMine([]);
    }
  }

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setError("");
      try {
        const [b, chRes] = await Promise.all([getBook(id), getBookChapters(id)]);
        const items = chRes?.items || [];
        if (cancelled) return;
        setBook(b);
        setChapters(items);
        const found = items.find((c) => String(c.id) === String(chapterId));
        setChapter(found || null);
        if (found) {
          const num = Number(found.chapter_number) || 1;
          await loadComments(num);
          await loadReactions(num);
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, chapterId]);

  const idx = chapters.findIndex((c) => String(c.id) === String(chapterId));
  if (guest && !isChapterAllowedForGuest(idx >= 0 ? idx : 0)) {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to keep reading</h3>
          <p>
            Guests can read the first {GUEST_CHAPTER_LIMIT} chapters. Sign in for the full story.
          </p>
          <Link className="btn btn-primary" to="/login">
            Sign in
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

  const prev = idx > 0 ? chapters[idx - 1] : null;
  const next = idx >= 0 && idx < chapters.length - 1 ? chapters[idx + 1] : null;
  const nextLocked = guest && next && !isChapterAllowedForGuest(idx + 1);

  const paragraphs = String(chapter.content || "")
    .split(/\n\n+/)
    .map((p) => p.trim())
    .filter(Boolean);

  function openPara(i) {
    setActivePara(i);
    setPanelOpen(true);
  }

  async function submitComment(e) {
    e.preventDefault();
    if (!getToken() || guest) {
      setMsg("Sign in to comment");
      return;
    }
    if (!draft.trim()) return;
    setBusy(true);
    try {
      await postChapterComment(id, chapterNumber, {
        body: draft.trim(),
        paragraph_index: activePara ?? -1,
      });
      setDraft("");
      await loadComments(chapterNumber);
      setMsg("Comment posted");
    } catch (err) {
      setMsg(String(err.message || err));
    } finally {
      setBusy(false);
    }
  }

  async function onReact(label) {
    if (!getToken() || guest) {
      setMsg("Sign in to react");
      return;
    }
    try {
      const res = await toggleChapterReaction(id, chapterNumber, label);
      setReactionCounts((prev) => ({
        ...prev,
        [label]: res?.count ?? (prev[label] || 0),
      }));
      if (res?.selected) {
        setMine((m) => (m.includes(label) ? m : [...m, label]));
      } else {
        setMine((m) => m.filter((x) => x !== label));
      }
      await loadReactions(chapterNumber);
    } catch (err) {
      setMsg(String(err.message || err));
    }
  }

  async function onSaveList() {
    if (!getToken() || guest) {
      setMsg("Sign in to save");
      return;
    }
    try {
      await addToReadingList(Number(id));
      setMsg("Saved to reading list");
    } catch (err) {
      setMsg(String(err.message || err));
    }
  }

  const panelComments =
    activePara == null
      ? comments
      : comments.filter((c) => Number(c.paragraph_index) === Number(activePara));

  return (
    <div className="inkitt-reader">
      <div className="inkitt-reader-grid">
        <aside className="reader-actions">
          <button type="button" className="story-action-btn" onClick={onSaveList}>
            🔖 Add to Reading List
          </button>
          <Link className="story-action-btn story-action-primary" to={`/stories/${id}`}>
            Write a Review
          </Link>
          {msg ? <p className="meta side-msg">{msg}</p> : null}
          <div className="reader-font-tools">
            <span className="meta">Customize readability</span>
            <div className="font-btns">
              <button type="button" className="story-action-btn">
                Aa
              </button>
            </div>
          </div>
        </aside>

        <article className="reader-main">
          <div className="reader-top-inline">
            <Link to={`/stories/${id}`} className="back-link">
              ← {book?.title || "Story"}
            </Link>
            <h1 className="chapter-heading">{chapter.title || `Chapter ${chapterNumber}`}</h1>
          </div>

          <div className="reader-paragraphs">
            {paragraphs.length ? (
              paragraphs.map((p, i) => {
                const count = Number(paraCounts[i] || paraCounts[String(i)] || 0);
                return (
                  <div key={i} className="para-row">
                    <p className="para-text">{p}</p>
                    <button
                      type="button"
                      className={`para-bubble ${count > 0 ? "has-comments" : ""}`}
                      onClick={() => openPara(i)}
                      title="Comments"
                    >
                      💬 {count > 0 ? count : 0}
                    </button>
                  </div>
                );
              })
            ) : (
              <p className="meta">Empty chapter.</p>
            )}
          </div>

          <div className="chapter-divider">〰</div>

          <section className="reactions-grid-wrap">
            <h3>Reactions</h3>
            <div className="reactions-grid">
              {REACTIONS.map((r) => {
                const count = Number(reactionCounts[r.label] || 0);
                const selected = mine.includes(r.label);
                return (
                  <button
                    key={r.label}
                    type="button"
                    className={`reaction-cell ${selected ? "selected" : ""}`}
                    onClick={() => onReact(r.label)}
                  >
                    <span className="reaction-emoji">{r.emoji}</span>
                    <span className="reaction-count">{count}</span>
                    <span className="reaction-label">{r.label}</span>
                  </button>
                );
              })}
            </div>
          </section>

          {nextLocked ? (
            <div className="guest-lock">
              <h3>Unlock the rest of this story</h3>
              <p>Sign in to read the next chapters.</p>
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
        </article>

        <aside className="reader-chapters-side">
          <details className="chapters-dropdown" open>
            <summary>
              Chapters
              <span className="meta">
                {chapterNumber}. {chapter.title || `Chapter ${chapterNumber}`}
              </span>
            </summary>
            <ul className="chapter-list chapter-list--panel">
              {chapters.map((c, i) => {
                const locked = guest && !isChapterAllowedForGuest(i);
                return (
                  <li key={c.id} className={locked ? "chapter-locked" : ""}>
                    {locked ? (
                      <span>
                        {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                        {c.title}
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
          </details>
        </aside>
      </div>

      {/* Comments slide-over panel */}
      {panelOpen && (
        <div className="comments-panel" role="dialog">
          <div className="comments-panel-head">
            <h2>Comments</h2>
            <button type="button" className="auth-close" onClick={() => setPanelOpen(false)}>
              ×
            </button>
          </div>
          {activePara != null && paragraphs[activePara] && (
            <blockquote className="comment-context">{paragraphs[activePara]}</blockquote>
          )}
          <ul className="comment-thread">
            {panelComments.map((c) => (
              <li key={c.id}>
                <strong>{c.display_name || "Reader"}</strong>
                <p>{c.body}</p>
                <span className="meta">{c.created_at || ""}</span>
              </li>
            ))}
            {panelComments.length === 0 && <li className="meta">No comments on this paragraph yet.</li>}
          </ul>
          <form className="comment-compose" onSubmit={submitComment}>
            <input
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder={guest ? "Sign in to write a comment…" : "Write a comment…"}
              disabled={guest}
            />
            <button type="submit" className="btn btn-primary" disabled={guest || busy}>
              Post
            </button>
          </form>
        </div>
      )}
    </div>
  );
}
