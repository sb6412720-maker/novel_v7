import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import BookCard from "../components/BookCard";
import { getMyStories } from "../api";
import { isGuestUser } from "../utils/guest";

export default function WritePage({ user }) {
  const [stories, setStories] = useState([]);
  const [error, setError] = useState("");
  const guest = isGuestUser(user);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (guest) return;
      try {
        const res = await getMyStories();
        const items = res?.items || res || [];
        if (!cancelled) setStories(Array.isArray(items) ? items : []);
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user, guest]);

  return (
    <div className="full-bleed writers-page">
      <section className="writers-hero">
        <div className="full-bleed-inner writers-hero-inner">
          <p className="writers-kicker">The reader-powered publisher</p>
          <h1>
            Stories start <em>here</em>
          </h1>
          <p className="lead">
            Publish your work, get discovered by readers on the same NovelHub platform as the mobile
            app. One database. One community.
          </p>
          {guest ? (
            <Link className="btn btn-primary" to="/login">
              Start writing — Sign in
            </Link>
          ) : (
            <p className="meta">Signed in as {user?.display_name || user?.email}. Manage stories below or in the app.</p>
          )}
        </div>
      </section>

      <div className="full-bleed-inner writers-body">
        <div className="writers-grid">
          {[
            ["Engaged community", "Readers like, comment, and return for the next chapter."],
            ["Shared with mobile", "Stories you publish appear in the Flutter app automatically."],
            ["Admin moderation", "Same MySQL DB — admin panel can review and feature titles."],
            ["Guest previews", "Visitors can sample the first 2 chapters; members read everything."],
          ].map(([t, d]) => (
            <div key={t} className="writers-card">
              <h3>{t}</h3>
              <p>{d}</p>
            </div>
          ))}
        </div>

        <h2 className="section-h">Your stories</h2>
        {guest && (
          <p className="meta">
            <Link to="/login">Sign in</Link> to see stories linked to your account (same as mobile Write
            tab).
          </p>
        )}
        {error && <div className="error-banner">{error}</div>}
        {!guest && (
          <div className="trending-grid">
            {stories.map((s) => (
              <div key={s.id} className="trending-cell">
                <BookCard book={s} variant="grid" />
              </div>
            ))}
          </div>
        )}
        {!guest && stories.length === 0 && (
          <p className="meta">
            No stories yet. Create one in the <strong>mobile Write</strong> tab or the admin panel —
            they show here from the same API.
          </p>
        )}
      </div>
    </div>
  );
}
