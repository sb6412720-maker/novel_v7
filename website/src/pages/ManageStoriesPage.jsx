import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { createChapter, createStory, getMyStories, resolveAssetUrl } from "../api";
import { isGuestUser } from "../utils/guest";

const SIDE_NAV = [
  { id: "manage", label: "Manage Stories", to: "/manage-stories" },
  { id: "analytics", label: "Analytics", soon: true },
  { id: "subscribers", label: "Subscribers", soon: true },
  { id: "subscription", label: "Manage Subscription", to: "/subscription" },
  { id: "experiments", label: "Experiments", soon: true },
];

export default function ManageStoriesPage({ user }) {
  const guest = isGuestUser(user);
  const navigate = useNavigate();
  const [tab, setTab] = useState("submitted");
  const [stories, setStories] = useState([]);
  const [q, setQ] = useState("");
  const [sort, setSort] = useState("recent");
  const [filter, setFilter] = useState("all");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [creating, setCreating] = useState(false);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const res = await getMyStories();
      setStories(res?.items || res || []);
    } catch (e) {
      setError(String(e.message || e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (guest) return;
    load();
  }, [guest]);

  async function onCreate() {
    if (creating) return;
    setCreating(true);
    setError("");
    try {
      const res = await createStory({
        title: "Untitled Story",
        description: "",
        status_text: "Draft",
        genre: "Romance",
      });
      const id = res?.id || res?.story_id || res?.item?.id;
      if (id) {
        try {
          await createChapter(id, {
            title: "Chapter 1",
            content: "",
            chapter_number: 1,
            status_text: "Draft",
          });
        } catch (_) {
          /* chapter may be auto-created by backend */
        }
        navigate(`/write/${id}`);
      } else {
        await load();
        navigate("/manage-stories");
      }
    } catch (e) {
      setError(String(e.message || e));
    } finally {
      setCreating(false);
    }
  }

  const filtered = useMemo(() => {
    let list = [...stories];
    list = list.filter((s) => {
      const status = String(s.status_text || s.status || "Published").toLowerCase();
      const isDraft = status.includes("draft") || status === "draft";
      if (tab === "drafts" && !isDraft) return false;
      if (tab === "submitted" && isDraft) return false;
      if (filter === "completed" && !s.is_completed) return false;
      if (q && !String(s.title || "").toLowerCase().includes(q.toLowerCase())) return false;
      return true;
    });
    if (sort === "title") {
      list.sort((a, b) => String(a.title || "").localeCompare(String(b.title || "")));
    } else if (sort === "rating") {
      list.sort((a, b) => Number(b.rating || 0) - Number(a.rating || 0));
    } else {
      list.sort((a, b) => Number(b.id || 0) - Number(a.id || 0));
    }
    return list;
  }, [stories, tab, q, sort, filter]);

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

  return (
    <div className="manage-page-inkitt">
      <div className="manage-banner" aria-hidden />

      <div className="manage-body">
        <aside className="manage-side">
          {SIDE_NAV.map((item) =>
            item.soon ? (
              <span key={item.id} className="manage-side-item muted">
                {item.label}
              </span>
            ) : (
              <Link
                key={item.id}
                to={item.to}
                className={`manage-side-item ${item.id === "manage" ? "active" : ""}`}
              >
                {item.label}
              </Link>
            )
          )}
        </aside>

        <main className="manage-content">
          <h1 className="manage-title">Manage Stories</h1>

          <div className="streak-card">
            <h3>Start your streak today</h3>
            <p>
              Your first writing session builds your chain. Looking forward to seeing it grow.{" "}
              <Link to="/write">See All →</Link>
            </p>
          </div>

          <div className="manage-toolbar">
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
            <button type="button" className="btn btn-primary create-story-btn" onClick={onCreate} disabled={creating}>
              {creating ? "Creating…" : "CREATE NEW STORY"}
            </button>
          </div>

          <div className="manage-filters">
            <label className="search-field">
              <span>Search</span>
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="Search"
              />
            </label>
            <label>
              <span>Sort by</span>
              <select value={sort} onChange={(e) => setSort(e.target.value)}>
                <option value="recent">Recently updated</option>
                <option value="title">Title</option>
                <option value="rating">Rating</option>
              </select>
            </label>
            <label>
              <span>Filter by</span>
              <select value={filter} onChange={(e) => setFilter(e.target.value)}>
                <option value="all">All stories</option>
                <option value="completed">Completed</option>
              </select>
            </label>
          </div>

          {error && <div className="error-banner">{error}</div>}
          {loading && <p className="meta">Loading…</p>}

          {!loading && filtered.length === 0 && (
            <div className="manage-empty">
              <div className="manage-empty-icon">📚</div>
              <h3>{tab === "drafts" ? "No drafts yet" : "No submitted stories yet"}</h3>
              <p>
                {tab === "drafts"
                  ? "Save a draft and it will appear here."
                  : "Once you submit a story, you'll find it here."}
              </p>
              <button type="button" className="btn btn-primary" onClick={onCreate} disabled={creating}>
                CREATE NEW STORY
              </button>
            </div>
          )}

          <div className="manage-story-grid">
            {filtered.map((s) => {
              const cover = resolveAssetUrl(s.cover_path || s.coverPath || "");
              return (
                <article key={s.id} className="manage-story-card">
                  <Link to={`/write/${s.id}`} className="manage-cover">
                    {cover ? (
                      <img src={cover} alt="" />
                    ) : (
                      <div className="manage-cover-ph" style={{ background: s.accent_hex || "#e5e7eb" }}>
                        {(s.title || "?")[0]}
                      </div>
                    )}
                  </Link>
                  <div className="manage-story-meta">
                    <Link to={`/write/${s.id}`}>
                      <h3>{s.title || "Untitled"}</h3>
                    </Link>
                    <p className="meta">
                      {s.status_text || "Published"} · {s.genre || s.primary_genre || "—"}
                    </p>
                    <div className="manage-story-actions">
                      <Link className="btn" to={`/write/${s.id}`}>
                        Edit
                      </Link>
                      <Link className="btn" to={`/stories/${s.id}`}>
                        View
                      </Link>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        </main>
      </div>
    </div>
  );
}
