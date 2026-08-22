import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { isGuestUser } from "../utils/guest";

const STORAGE_KEY = "novelhub_contests_v1";

const DEFAULTS = [
  {
    id: "1",
    title: "Love in Full Color",
    theme: "Every kind of love, every kind of story. Writing Contest 2026.",
    deadline: "Open entry",
    active: true,
    neon: true,
  },
  {
    id: "2",
    title: "Dark Romance Challenge",
    theme: "Forbidden love, tension, and second chances.",
    deadline: "Open entry",
    active: true,
  },
  {
    id: "3",
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

  // Any signed-in non-guest can manage local contest cards (shared DB contests API later)
  const canManage = user && !isGuestUser(user);

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
      <section className="contest-neon contest-neon--page">
        <div className="contest-neon-inner">
          <h1 className="neon-title">
            LOVE IN
            <br />
            FULL COLOR
          </h1>
          <div className="neon-copy">
            <p className="neon-kicker">WRITING CONTEST 2026</p>
            <p>Every kind of love, every kind of story.</p>
            <Link className="btn btn-neon" to="/write">
              ENTER NOW
            </Link>
          </div>
        </div>
      </section>

      <div className="full-bleed-inner page">
        <header className="page-header">
          <h2>Writing Contests</h2>
          <p className="meta">
            Enter via Write. Stories use the same MySQL database as the mobile app. Signed-in users
            can manage contest cards on this device.
          </p>
        </header>

        {canManage && (
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
                {adminMode && canManage && (
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
