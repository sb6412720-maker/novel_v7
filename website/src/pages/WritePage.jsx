import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import BookCard from "../components/BookCard";
import { getMyStories } from "../api";

export default function WritePage({ user }) {
  const [stories, setStories] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await getMyStories();
        if (!cancelled) setStories(res?.items || res || []);
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user]);

  return (
    <div className="container page">
      <header className="page-header">
        <h1>Write</h1>
        <p className="meta">
          Manage stories created in the mobile app. Full web editor can be expanded later — data is
          already on the shared backend.
        </p>
      </header>
      {error && <div className="error-banner">{error}</div>}
      <div className="book-grid">
        {stories.map((s) => (
          <BookCard key={s.id} book={s} />
        ))}
      </div>
      {stories.length === 0 && (
        <p className="meta">
          No stories yet. Create one in the mobile Write tab, or use the admin panel.{" "}
          <Link to="/discover">Browse stories</Link>
        </p>
      )}
    </div>
  );
}
