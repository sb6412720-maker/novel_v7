import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  createChapter,
  deleteChapter,
  deleteStory,
  getBook,
  getBookChapters,
  getWriteStory,
  resolveAssetUrl,
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
  "Dark Romance",
  "Contemporary Romance",
  "LGBTQ+",
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
  const [showSettings, setShowSettings] = useState(false);

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
  const [newChapterName, setNewChapterName] = useState("");

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
    e?.preventDefault?.();
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
      setMsg("Story saved");
      setShowSettings(false);
      await reload();
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setSavingStory(false);
    }
  }

  async function onSaveChapter(e) {
    e?.preventDefault?.();
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

  async function onSubmitChapter() {
    if (!activeChapterId) return;
    const text = String(chapterForm.content || "").trim();
    if (text.length < 50) {
      setError("Chapter needs at least 50 characters to publish. Saved as draft.");
      setSavingChapter(true);
      try {
        await updateChapter(activeChapterId, {
          title: chapterForm.title,
          content: chapterForm.content,
          chapter_number: Number(chapterForm.chapter_number) || 1,
          submission_status: "draft",
        });
        setMsg("Saved as draft (under 50 characters)");
        await reload();
      } catch (err) {
        setError(String(err.message || err));
      } finally {
        setSavingChapter(false);
      }
      return;
    }
    setSavingChapter(true);
    setError("");
    try {
      await updateChapter(activeChapterId, {
        title: chapterForm.title,
        content: chapterForm.content,
        chapter_number: Number(chapterForm.chapter_number) || 1,
        submission_status: "published",
      });
      // If story was draft and has a published chapter, mark published
      try {
        await updateStory(storyId, {
          title: meta.title,
          author: meta.author,
          description: meta.description,
          genre: meta.genre,
          status_text: "Published",
          content_warnings: meta.content_warnings,
        });
      } catch {
        /* optional */
      }
      setMsg("Chapter submitted / published");
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
      const title = newChapterName.trim() || `Chapter ${nextNum}`;
      const res = await createChapter(storyId, {
        title,
        content: "",
        chapter_number: nextNum,
        submission_status: "draft",
      });
      const newId = res?.id || res?.chapter_id;
      setNewChapterName("");
      await reload();
      if (newId) {
        setActiveChapterId(newId);
        setChapterForm({ title, content: "", chapter_number: nextNum });
      }
      setMsg("Chapter created");
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
      navigate("/manage-stories");
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  if (guest) {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to edit</h3>
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

  const cover = resolveAssetUrl(story?.cover_path || "");

  return (
    <div className="inkitt-editor">
      <div className="inkitt-editor-bar">
        <Link to="/manage-stories" className="back-link">
          ← Manage Stories
        </Link>
        <div className="inkitt-editor-bar-actions">
          <button type="button" className="btn" onClick={() => setShowSettings((v) => !v)}>
            Settings
          </button>
          <Link className="btn" to={`/stories/${storyId}`}>
            Preview
          </Link>
          <button type="button" className="btn" onClick={onSaveChapter} disabled={savingChapter}>
            💾 Save
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={onSubmitChapter}
            disabled={savingChapter || !activeChapterId}
          >
            Submit Chapter
          </button>
        </div>
      </div>

      {error && <div className="error-banner container">{error}</div>}
      {msg && <p className="meta save-msg container">{msg}</p>}

      {showSettings && (
        <form className="write-form card-panel container" onSubmit={onSaveStory}>
          <h2>Story settings</h2>
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
          <div className="form-actions">
            <button type="button" className="btn btn-danger" onClick={onDeleteStory}>
              Delete story
            </button>
            <button type="submit" className="btn btn-primary" disabled={savingStory}>
              {savingStory ? "Saving…" : "Save settings"}
            </button>
          </div>
        </form>
      )}

      <div className="inkitt-editor-grid">
        <aside className="inkitt-editor-cover">
          <div className="editor-cover-box">
            {cover ? (
              <img src={cover} alt="" />
            ) : (
              <div className="editor-cover-empty">
                <span>{(meta.title || "?")[0]}</span>
              </div>
            )}
          </div>
          <button type="button" className="btn editor-cover-btn" disabled title="Cover upload via mobile/admin">
            Edit Story Cover
          </button>
        </aside>

        <main className="inkitt-editor-main">
          <div className="editor-story-title-row">
            <h1 className="editor-story-title">{meta.title || "UNTITLED STORY"}</h1>
            <button type="button" className="linkish" onClick={() => setShowSettings(true)}>
              Edit Title
            </button>
          </div>
          {activeChapterId ? (
            <form onSubmit={onSaveChapter}>
              <h2 className="editor-chapter-title">
                <input
                  className="chapter-title-input"
                  value={chapterForm.title}
                  onChange={(e) => setChapterForm({ ...chapterForm, title: e.target.value })}
                  placeholder="Chapter title"
                />
              </h2>
              <div className="editor-toolbar" aria-hidden>
                <span>B</span>
                <span>I</span>
                <span>¶</span>
              </div>
              <textarea
                className="chapter-content inkitt-chapter-body"
                rows={20}
                value={chapterForm.content}
                onChange={(e) => setChapterForm({ ...chapterForm, content: e.target.value })}
                placeholder="Start writing here…"
              />
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
            <p className="meta">Select a chapter or create one.</p>
          )}
        </main>

        <aside className="inkitt-editor-chapters">
          <h3>CHAPTERS</h3>
          <ul className="editor-ch-list">
            {chapters.map((c) => (
              <li key={c.id}>
                <button
                  type="button"
                  className={String(c.id) === String(activeChapterId) ? "active" : ""}
                  onClick={() => selectChapter(c)}
                >
                  <strong>
                    {c.chapter_number != null ? `Chapter ${c.chapter_number}` : c.title}
                  </strong>
                  <span className="meta">{c.title}</span>
                  <span className="ch-status">
                    {(c.submission_status || "draft").toLowerCase() === "published"
                      ? "Submitted"
                      : "Not Submitted"}
                  </span>
                </button>
              </li>
            ))}
          </ul>
          <div className="create-ch-box">
            <label>Create New Chapter:</label>
            <input
              value={newChapterName}
              onChange={(e) => setNewChapterName(e.target.value)}
              placeholder="Enter Chapter Name"
            />
            <button type="button" className="btn btn-primary" onClick={onAddChapter} disabled={savingChapter}>
              + Create Chapter
            </button>
          </div>
          <div className="upload-ms-note meta">
            Upload Manuscript (Word .doc/.docx) — use mobile app or paste text for now.
          </div>
        </aside>
      </div>
    </div>
  );
}
