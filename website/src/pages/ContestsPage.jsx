import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { isGuestUser } from "../utils/guest";

const STORAGE_KEY = "novelhub_contests_v1";

const DEFAULTS = [
  {
    id: "1",
    title: "Dark Romance Challenge",
    theme: "Forbidden love, tension, and second chances.",
    deadline: "Open entry",
    active: true,
  },
  {
    id: "2",
    title: "Myth Weaver",
    theme: "Mythology-inspired romance or drama.",
    deadline: "Open entry",
    active: true,
  },
];

function loadContests() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch {
    /* ignore */
  }
  return DEFAULTS;
}

export default function ContestsPage({ user }) {
  const [contests, setContests] = useState(DEFAULTS);
  const [adminMode, setAdminMode] = useState(false);
  const [form, setForm] = useState({ title: "", theme: "", deadline: "" });
  const isAdmin =
    user &&
    !isGuestUser(user) &&
    (String(user.email || "").includes("admin") || user.is_admin || user.role === "admin");

  useEffect(() => {
    setContests(loadContests());
  }, []);

  function save(list) {
    setContests(list);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
  }

  function addContest(e) {
    e.preventDefault();
    if (!form.title.trim()) return;
    const next = [
      {
        id: String(Date.now()),
        title: form.title.trim(),
        theme: form.theme.trim(),
        deadline: form.deadline.trim() || "Open entry",
        active: true,
      },
      ...contests,
    ];
    save(next);
    setForm({ title: "", theme: "", deadline: "" });
  }

  function removeContest(id) {
    save(contests.filter((c) => c.id !== id));
  }

  return (
    <div className="full-bleed">
      <div className="full-bleed-inner page">
        <header className="page-header">
          <h1>Writing Contests</h1>
          <p className="meta">
            Enter via Write. Stories live in the shared MySQL database. Admin can manage contest
            cards here (local list until contests API is added to admin panel).
          </p>
        </header>

        {isAdmin && (
          <div className="card-panel">
            <button type="button" className="btn" onClick={() => setAdminMode((v) => !v)}>
              {adminMode ? "Close manager" : "Manage contests"}
            </button>
            {adminMode && (
              <form className="write-form" style={{ marginTop: 16 }} onSubmit={addContest}>
                <label>
                  Title
                  <input
                    value={form.title}
                    onChange={(e) => setForm({ ...form, title: e.target.value })}
                    required
                  />
                </label>
                <label>
                  Theme
                  <input
                    value={form.theme}
                    onChange={(e) => setForm({ ...form, theme: e.target.value })}
                  />
                </label>
                <label>
                  Deadline
                  <input
                    value={form.deadline}
                    onChange={(e) => setForm({ ...form, deadline: e.target.value })}
                  />
                </label>
                <button type="submit" className="btn btn-primary">
                  Add contest
                </button>
              </form>
            )}
          </div>
        )}

        <div className="contest-list">
          {contests.map((c) => (
            <article key={c.id} className="contest-card">
              <h2>{c.title}</h2>
              <p>{c.theme}</p>
              <p className="meta">Deadline: {c.deadline}</p>
              <div className="form-actions" style={{ justifyContent: "flex-start" }}>
                <Link className="btn btn-primary" to="/write">
                  Enter via Write
                </Link>
                {adminMode && isAdmin && (
                  <button type="button" className="btn btn-danger" onClick={() => removeContest(c.id)}>
                    Delete
                  </button>
                )}
              </div>
            </article>
          ))}
        </div>
      </div>
    </div>
  );
}
