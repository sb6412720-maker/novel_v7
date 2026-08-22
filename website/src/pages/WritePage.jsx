import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import BookCard from "../components/BookCard";
import { createStory, getMyStories, resolveAssetUrl } from "../api";
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

export default function WritePage({ user }) {
  const navigate = useNavigate();
  const [stories, setStories] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    title: "",
    author: "",
    description: "",
    genre: "Romance",
    status_text: "Published",
    content_warnings: "",
  });
  const guest = isGuestUser(user);

  async function loadStories() {
    if (guest) return;
    setLoading(true);
    setError("");
    try {
      const res = await getMyStories();
      const items = res?.items || res || [];
      setStories(Array.isArray(items) ? items : []);
    } catch (e) {
      setError(String(e.message || e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadStories();
    if (user && !guest) {
      setForm((f) => ({
        ...f,
        author: f.author || user.display_name || user.username || "",
      }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, guest]);

  async function onCreate(e) {
    e.preventDefault();
    if (!form.title.trim()) {
      setError("Title is required");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const res = await createStory({
        title: form.title.trim(),
        author: form.author.trim() || user?.display_name || "Author",
        description: form.description.trim(),
        genre: form.genre,
        cover_path: "",
        tags: [],
        content_warnings: form.content_warnings.trim(),
        status_text: form.status_text,
      });
      const id = res?.id || res?.story_id || res?.book_id;
      setShowNew(false);
      setForm((f) => ({ ...f, title: "", description: "" }));
      if (id) navigate(`/write/stories/${id}`);
      else await loadStories();
    } catch (err) {
      setError(err.status === 401 ? "Sign in to create a story" : String(err.message || err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="full-bleed writers-page">
      <section className="writers-hero">
        <div className="full-bleed-inner writers-hero-inner">
          <p className="writers-kicker">Write on NovelHub</p>
          <h1>
            Stories start <em>here</em>
          </h1>
          <p className="lead">
            Create stories and chapters in the browser. They sync to the same MySQL database as the
            mobile app and admin panel.
          </p>
          {guest ? (
            <Link className="btn btn-primary" to="/login">
              Sign in to write
            </Link>
          ) : (
            <button type="button" className="btn btn-primary" onClick={() => setShowNew(true)}>
              + New story
            </button>
            <Link className="btn" to="/manage-stories" style={{ marginLeft: 8 }}>
              Manage Stories
            </Link>
          )}
        </div>
      </section>

      <div className="full-bleed-inner writers-body">
        {error && <div className="error-banner">{error}</div>}

        {showNew && !guest && (
          <form className="write-form card-panel" onSubmit={onCreate}>
            <h2>New story</h2>
            <label>
              Title
              <input
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                required
                maxLength={200}
              />
            </label>
            <label>
              Author name
              <input
                value={form.author}
                onChange={(e) => setForm({ ...form, author: e.target.value })}
                maxLength={120}
              />
            </label>
            <label>
              Genre
              <select
                value={form.genre}
                onChange={(e) => setForm({ ...form, genre: e.target.value })}
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
                value={form.status_text}
                onChange={(e) => setForm({ ...form, status_text: e.target.value })}
              >
                <option value="Published">Published</option>
                <option value="Draft">Draft</option>
              </select>
            </label>
            <label>
              Summary
              <textarea
                rows={4}
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="Hook readers in a few sentences…"
              />
            </label>
            <label>
              Content warnings (optional)
              <input
                value={form.content_warnings}
                onChange={(e) => setForm({ ...form, content_warnings: e.target.value })}
              />
            </label>
            <div className="form-actions">
              <button type="button" className="btn" onClick={() => setShowNew(false)}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? "Creating…" : "Create & edit chapters"}
              </button>
            </div>
          </form>
        )}

        <h2 className="section-h">Your stories</h2>
        {guest && (
          <p className="meta">
            <Link to="/login">Sign in</Link> with the same account as the mobile app to manage
            stories.
          </p>
        )}
        {loading && <p className="meta">Loading…</p>}
        {!guest && (
          <div className="write-story-list">
            {stories.map((s) => {
              const cover = resolveAssetUrl(s.cover_path || s.coverPath || "");
              return (
                <div key={s.id} className="write-story-row">
                  <div className="write-story-cover">
                    {cover ? (
                      <img src={cover} alt="" />
                    ) : (
                      <div className="write-story-cover-fallback">{(s.title || "?")[0]}</div>
                    )}
                  </div>
                  <div className="write-story-info">
                    <h3>{s.title}</h3>
                    <p className="meta">
                      {s.genre || "—"} · {s.status_text || "Published"}
                    </p>
                  </div>
                  <div className="write-story-actions">
                    <Link className="btn btn-primary" to={`/write/stories/${s.id}`}>
                      Edit
                    </Link>
                    <Link className="btn" to={`/stories/${s.id}`}>
                      View
                    </Link>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {!guest && !loading && stories.length === 0 && (
          <p className="meta">No stories yet. Click <strong>New story</strong> to start.</p>
        )}

        {!guest && stories.length > 0 && (
          <div className="trending-grid" style={{ marginTop: 32 }}>
            {stories.map((s) => (
              <div key={`card-${s.id}`} className="trending-cell">
                <BookCard book={s} variant="grid" />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
