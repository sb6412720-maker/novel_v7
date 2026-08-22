import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { getMyStories, resolveAssetUrl } from "../api";
import { isGuestUser } from "../utils/guest";

export default function ManageStoriesPage({ user }) {
  const guest = isGuestUser(user);
  const [tab, setTab] = useState("submitted");
  const [stories, setStories] = useState([]);
  const [q, setQ] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (guest) return;
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const res = await getMyStories();
        if (!cancelled) setStories(res?.items || res || []);
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [guest]);

  if (guest) {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to manage stories</h3>
          <Link className="btn btn-primary" to="/login">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  const filtered = stories.filter((s) => {
    const status = (s.status_text || "Published").toLowerCase();
    const isDraft = status.includes("draft");
    if (tab === "drafts" && !isDraft) return false;
    if (tab === "submitted" && isDraft) return false;
    if (q && !String(s.title || "").toLowerCase().includes(q.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="manage-stories-page">
      <div className="manage-layout">
        <aside className="manage-nav">
          <Link className="manage-nav-item active" to="/manage-stories">
            Manage Stories
          </Link>
          <span className="manage-nav-item disabled">Analytics</span>
          <span className="manage-nav-item disabled">Subscribers</span>
          <Link className="manage-nav-item" to="/write">
            Write
          </Link>
        </aside>

        <main className="manage-main">
          <div className="manage-header">
            <h1>Manage Stories</h1>
            <Link className="btn btn-primary" to="/write">
              CREATE NEW STORY
            </Link>
          </div>

          <div className="manage-tabs">
            <button
              type="button"
              className={tab === "submitted" ? "active" : ""}
              onClick={() => setTab("submitted")}
            >
              Submitted
            </button>
            <button
              type="button"
              className={tab === "drafts" ? "active" : ""}
              onClick={() => setTab("drafts")}
            >
              Drafts
            </button>
          </div>

          <div className="manage-filters">
            <input
              placeholder="Search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>

          {error && <div className="error-banner">{error}</div>}
          {loading && <p className="meta">Loading…</p>}

          {!loading && filtered.length === 0 && (
            <div className="manage-empty">
              <div className="manage-empty-icon">📚</div>
              <h3>No {tab === "drafts" ? "draft" : "submitted"} stories yet</h3>
              <p className="meta">Once you submit a story, you’ll find it here.</p>
              <Link className="btn btn-primary" to="/write">
                CREATE NEW STORY
              </Link>
            </div>
          )}

          <ul className="manage-story-list">
            {filtered.map((s) => {
              const cover = resolveAssetUrl(s.cover_path || "");
              return (
                <li key={s.id} className="manage-story-row">
                  <div className="manage-cover">
                    {cover ? <img src={cover} alt="" /> : <div className="cover-ph">{(s.title || "?")[0]}</div>}
                  </div>
                  <div className="manage-info">
                    <h3>{s.title}</h3>
                    <p className="meta">
                      {s.genre || "—"} · {s.status_text || "Published"}
                    </p>
                  </div>
                  <div className="manage-actions">
                    <Link className="btn btn-primary" to={`/write/stories/${s.id}`}>
                      Edit
                    </Link>
                    <Link className="btn" to={`/stories/${s.id}`}>
                      View
                    </Link>
                  </div>
                </li>
              );
            })}
          </ul>
        </main>
      </div>
    </div>
  );
}
