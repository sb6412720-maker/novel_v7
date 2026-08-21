import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  createChapter,
  deleteChapter,
  deleteStory,
  getBook,
  getBookChapters,
  getWriteStory,
  updateChapter,
  updateStory,
} from "../api";
import { isGuestUser } from "../utils/guest";

const GENRES = [
  "Romance",
  "Fantasy",
  "Thriller",
  "Young Adult",
  "Sci-Fi",
  "Drama",
  "Adventure",
  "Mystery",
  "Horror",
  "Other",
];

export default function StoryEditorPage({ user }) {
  const { storyId } = useParams();
  const navigate = useNavigate();
  const guest = isGuestUser(user);

  const [story, setStory] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [loading, setLoading] = useState(true);
  const [savingStory, setSavingStory] = useState(false);
  const [savingChapter, setSavingChapter] = useState(false);

  const [meta, setMeta] = useState({
    title: "",
    author: "",
    description: "",
    genre: "Romance",
    status_text: "Published",
    content_warnings: "",
  });

  const [activeChapterId, setActiveChapterId] = useState(null);
  const [chapterForm, setChapterForm] = useState({
    title: "",
    content: "",
    chapter_number: 1,
  });

  async function reload() {
    setLoading(true);
    setError("");
    try {
      const [s, ch] = await Promise.all([
        getWriteStory(storyId).catch(() => getBook(storyId).catch(() => null)),
        getBookChapters(storyId),
      ]);
      const items = ch?.items || [];
      setChapters(items);
      if (s) {
        setStory(s);
        setMeta({
          title: s.title || "",
          author: s.author || "",
          description: s.description || "",
          genre: s.genre || s.primary_genre || "Romance",
          status_text: s.status_text || "Published",
          content_warnings: s.content_warnings || "",
        });
      }
      if (items.length && activeChapterId == null) {
        selectChapter(items[0]);
      } else if (activeChapterId) {
        const found = items.find((c) => String(c.id) === String(activeChapterId));
        if (found) selectChapter(found);
      }
    } catch (e) {
      setError(String(e.message || e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (guest) return;
    reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storyId, guest]);

  function selectChapter(c) {
    setActiveChapterId(c.id);
    setChapterForm({
      title: c.title || "",
      content: c.content || "",
      chapter_number: c.chapter_number ?? 1,
    });
  }

  async function onSaveStory(e) {
    e.preventDefault();
    setSavingStory(true);
    setMsg("");
    setError("");
    try {
      await updateStory(storyId, {
        title: meta.title,
        author: meta.author,
        description: meta.description,
        genre: meta.genre,
        status_text: meta.status_text,
        content_warnings: meta.content_warnings,
      });
      setMsg("Story details saved");
      await reload();
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setSavingStory(false);
    }
  }

  async function onSaveChapter(e) {
    e.preventDefault();
    if (!activeChapterId) return;
    setSavingChapter(true);
    setMsg("");
    setError("");
    try {
      await updateChapter(activeChapterId, {
        title: chapterForm.title,
        content: chapterForm.content,
        chapter_number: Number(chapterForm.chapter_number) || 1,
        submission_status: "published",
      });
      setMsg("Chapter saved");
      await reload();
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setSavingChapter(false);
    }
  }

  async function onAddChapter() {
    setSavingChapter(true);
    setError("");
    try {
      const nextNum =
        chapters.reduce((m, c) => Math.max(m, Number(c.chapter_number) || 0), 0) + 1;
      const res = await createChapter(storyId, {
        title: `Chapter ${nextNum}`,
        content: "",
        chapter_number: nextNum,
        submission_status: "draft",
      });
      const newId = res?.id || res?.chapter_id;
      await reload();
      if (newId) {
        setActiveChapterId(newId);
        setChapterForm({ title: `Chapter ${nextNum}`, content: "", chapter_number: nextNum });
      }
      setMsg("Chapter added");
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setSavingChapter(false);
    }
  }

  async function onDeleteChapter() {
    if (!activeChapterId) return;
    if (!window.confirm("Delete this chapter permanently?")) return;
    try {
      await deleteChapter(activeChapterId);
      setActiveChapterId(null);
      setChapterForm({ title: "", content: "", chapter_number: 1 });
      setMsg("Chapter deleted");
      await reload();
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  async function onDeleteStory() {
    if (!window.confirm("Delete this entire story and its chapters?")) return;
    try {
      await deleteStory(storyId);
      navigate("/write");
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  if (guest) {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to edit</h3>
          <p>Use the same account as the mobile app.</p>
          <Link className="btn btn-primary" to="/login">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  if (loading && !story) {
    return <div className="container page">Loading editor…</div>;
  }

  return (
    <div className="full-bleed editor-page">
      <div className="full-bleed-inner editor-layout">
        <div className="editor-top">
          <Link to="/write" className="back-link">
            ← Your stories
          </Link>
          <Link className="btn" to={`/stories/${storyId}`}>
            Public view
          </Link>
        </div>

        {error && <div className="error-banner">{error}</div>}
        {msg && <p className="meta save-msg">{msg}</p>}

        <form className="write-form card-panel" onSubmit={onSaveStory}>
          <h2>Story details</h2>
          <div className="form-grid">
            <label>
              Title
              <input
                value={meta.title}
                onChange={(e) => setMeta({ ...meta, title: e.target.value })}
                required
              />
            </label>
            <label>
              Author
              <input
                value={meta.author}
                onChange={(e) => setMeta({ ...meta, author: e.target.value })}
              />
            </label>
            <label>
              Genre
              <select
                value={meta.genre}
                onChange={(e) => setMeta({ ...meta, genre: e.target.value })}
              >
                {GENRES.map((g) => (
                  <option key={g} value={g}>
                    {g}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Status
              <select
                value={meta.status_text}
                onChange={(e) => setMeta({ ...meta, status_text: e.target.value })}
              >
                <option value="Published">Published</option>
                <option value="Draft">Draft</option>
              </select>
            </label>
          </div>
          <label>
            Summary
            <textarea
              rows={3}
              value={meta.description}
              onChange={(e) => setMeta({ ...meta, description: e.target.value })}
            />
          </label>
          <label>
            Content warnings
            <input
              value={meta.content_warnings}
              onChange={(e) => setMeta({ ...meta, content_warnings: e.target.value })}
            />
          </label>
          <div className="form-actions">
            <button type="button" className="btn btn-danger" onClick={onDeleteStory}>
              Delete story
            </button>
            <button type="submit" className="btn btn-primary" disabled={savingStory}>
              {savingStory ? "Saving…" : "Save story"}
            </button>
          </div>
        </form>

        <div className="editor-chapters card-panel">
          <div className="editor-chapters-head">
            <h2>Chapters ({chapters.length})</h2>
            <button type="button" className="btn btn-primary" onClick={onAddChapter} disabled={savingChapter}>
              + Add chapter
            </button>
          </div>

          <div className="editor-chapters-body">
            <ul className="chapter-sidebar">
              {chapters.map((c) => (
                <li key={c.id}>
                  <button
                    type="button"
                    className={String(c.id) === String(activeChapterId) ? "active" : ""}
                    onClick={() => selectChapter(c)}
                  >
                    {c.chapter_number != null ? `${c.chapter_number}. ` : ""}
                    {c.title || "Untitled"}
                  </button>
                </li>
              ))}
              {chapters.length === 0 && <li className="meta">No chapters — add one.</li>}
            </ul>

            {activeChapterId ? (
              <form className="chapter-editor" onSubmit={onSaveChapter}>
                <div className="form-grid">
                  <label>
                    Chapter number
                    <input
                      type="number"
                      min={1}
                      value={chapterForm.chapter_number}
                      onChange={(e) =>
                        setChapterForm({ ...chapterForm, chapter_number: e.target.value })
                      }
                    />
                  </label>
                  <label>
                    Title
                    <input
                      value={chapterForm.title}
                      onChange={(e) => setChapterForm({ ...chapterForm, title: e.target.value })}
                      required
                    />
                  </label>
                </div>
                <label>
                  Content
                  <textarea
                    className="chapter-content"
                    rows={18}
                    value={chapterForm.content}
                    onChange={(e) => setChapterForm({ ...chapterForm, content: e.target.value })}
                    placeholder="Write your chapter… Use blank lines between paragraphs."
                  />
                </label>
                <div className="form-actions">
                  <button type="button" className="btn btn-danger" onClick={onDeleteChapter}>
                    Delete chapter
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={savingChapter}>
                    {savingChapter ? "Saving…" : "Save chapter"}
                  </button>
                </div>
              </form>
            ) : (
              <p className="meta">Select a chapter or add a new one.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
