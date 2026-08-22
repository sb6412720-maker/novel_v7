import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  adminCreateContest,
  adminDeleteContest,
  getContests,
  getToken,
} from "../api";
import { isGuestUser } from "../utils/guest";

export default function ContestsPage({ user }) {
  const [contests, setContests] = useState([]);
  const [adminMode, setAdminMode] = useState(false);
  const [form, setForm] = useState({ title: "", theme: "", deadline: "" });
  const [error, setError] = useState("");
  const canManage = user && !isGuestUser(user) && getToken();

  async function load() {
    try {
      const res = await getContests();
      setContests(res?.items || []);
    } catch (e) {
      setError(String(e.message || e));
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function addContest(e) {
    e.preventDefault();
    if (!form.title.trim()) return;
    try {
      await adminCreateContest({
        title: form.title.trim(),
        theme: form.theme.trim(),
        deadline: form.deadline.trim() || "Open entry",
        is_active: true,
        is_neon: false,
      });
      setForm({ title: "", theme: "", deadline: "" });
      await load();
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  async function removeContest(id) {
    try {
      await adminDeleteContest(id);
      await load();
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  const neon = contests.find((c) => c.is_neon) || contests[0];

  return (
    <div className="full-bleed">
      <section className="contest-neon contest-neon--page">
        <div className="contest-neon-inner">
          <h1 className="neon-title">
            {(neon?.title || "LOVE IN FULL COLOR").toUpperCase().split(" ").slice(0, 3).join(" ")}
          </h1>
          <div className="neon-copy">
            <p className="neon-kicker">WRITING CONTEST</p>
            <p>{neon?.theme || "Every kind of love, every kind of story."}</p>
            <Link className="btn btn-neon" to="/write">
              ENTER NOW
            </Link>
          </div>
        </div>
      </section>

      <div className="full-bleed-inner page">
        <header className="page-header">
          <h2>Writing Contests</h2>
          <p className="meta">Stored in MySQL — same database as mobile and admin.</p>
        </header>

        {error && <div className="error-banner">{error}</div>}

        {canManage && (
          <div className="card-panel">
            <button type="button" className="btn" onClick={() => setAdminMode((v) => !v)}>
              {adminMode ? "Close manager" : "Manage contests (DB)"}
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
          {!contests.length && (
            <p className="meta">No contests yet. Restart backend to seed defaults, or add one above.</p>
          )}
        </div>
      </div>
    </div>
  );
}
