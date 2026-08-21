import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { getActivityFeed, getMe, getUserWall, postUserWall, getToken } from "../api";
import { isGuestUser } from "../utils/guest";

export default function CommunityPage({ user }) {
  const guest = isGuestUser(user);
  const [wall, setWall] = useState([]);
  const [activity, setActivity] = useState([]);
  const [body, setBody] = useState("");
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [targetId, setTargetId] = useState(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        let uid = user?.id || user?.user_id;
        if (!uid && getToken()) {
          const me = await getMe();
          uid = me?.id || me?.user_id;
        }
        if (!uid) {
          // public sample: skip
          return;
        }
        if (!cancelled) setTargetId(uid);
        const [w, a] = await Promise.all([
          getUserWall(uid).catch(() => ({ items: [] })),
          getActivityFeed(uid).catch(() => ({ items: [] })),
        ]);
        if (!cancelled) {
          setWall(w?.items || w || []);
          setActivity(a?.items || a || []);
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user]);

  async function onPost(e) {
    e.preventDefault();
    if (!targetId || !body.trim()) return;
    try {
      await postUserWall(targetId, body.trim());
      setBody("");
      setMsg("Posted");
      const w = await getUserWall(targetId);
      setWall(w?.items || w || []);
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  return (
    <div className="full-bleed">
      <div className="full-bleed-inner page">
        <header className="page-header">
          <h1>Community</h1>
          <p className="meta">Wall and activity from the same MySQL backend as the mobile app.</p>
        </header>

        {error && <div className="error-banner">{error}</div>}
        {msg && <p className="meta">{msg}</p>}

        {guest ? (
          <p className="meta">
            <Link to="/login">Sign in</Link> to post on your wall and see personal activity.
          </p>
        ) : (
          <form className="wall-compose" onSubmit={onPost}>
            <textarea
              rows={3}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Share something with the community…"
            />
            <button type="submit" className="btn btn-primary">
              Post
            </button>
          </form>
        )}

        <div className="community-cols">
          <section>
            <h2 className="section-h">Wall</h2>
            <ul className="wall-list">
              {(wall || []).map((p) => (
                <li key={p.id}>
                  <strong>{p.display_name || p.sender_name || "User"}</strong>
                  <p>{p.body || p.message}</p>
                  <span className="meta">{p.created_at || ""}</span>
                </li>
              ))}
              {(!wall || wall.length === 0) && <li className="meta">No wall posts yet.</li>}
            </ul>
          </section>
          <section>
            <h2 className="section-h">Activity</h2>
            <ul className="wall-list">
              {(activity || []).map((a) => (
                <li key={a.id}>
                  <strong>{a.title || a.type}</strong>
                  <p>{a.message || ""}</p>
                  <span className="meta">{a.created_at || ""}</span>
                </li>
              ))}
              {(!activity || activity.length === 0) && (
                <li className="meta">No activity yet. Likes and reviews on your books appear here.</li>
              )}
            </ul>
          </section>
        </div>
      </div>
    </div>
  );
}
