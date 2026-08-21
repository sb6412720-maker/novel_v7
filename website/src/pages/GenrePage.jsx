import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import BookCard from "../components/BookCard";
import { getBootstrap } from "../api";

function collectBooks(data) {
  if (!data) return [];
  const map = new Map();
  for (const list of [data.books, data.recently_updated, data.recently_completed, data.featured]) {
    if (!Array.isArray(list)) continue;
    for (const b of list) {
      if (b?.id != null && !map.has(b.id)) map.set(b.id, b);
    }
  }
  return [...map.values()];
}

export default function GenrePage() {
  const { genre } = useParams();
  const label = decodeURIComponent(genre || "Stories");
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const boot = await getBootstrap();
        if (!cancelled) setBooks(collectBooks(boot));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = useMemo(() => {
    const g = label.toLowerCase();
    return books.filter((b) => {
      const hay = `${b.genre || ""} ${b.primary_genre || ""} ${b.title || ""}`.toLowerCase();
      return hay.includes(g) || g === "more" || g === "stories";
    });
  }, [books, label]);

  return (
    <div className="full-bleed">
      <div className="full-bleed-inner">
        <div className="genre-page-header">
          <p className="meta">
            <Link to="/">Home</Link> · {label}
          </p>
          <h1>{label} Stories</h1>
          <p className="meta">{filtered.length} stories · same database as the app</p>
        </div>
        {loading ? <p className="meta">Loading…</p> : null}
        <div className="trending-grid" style={{ marginBottom: 48 }}>
          {filtered.map((b) => (
            <div key={b.id} className="trending-cell">
              <BookCard book={b} variant="grid" />
            </div>
          ))}
        </div>
        {!loading && filtered.length === 0 ? (
          <p className="meta">No stories in this genre yet.</p>
        ) : null}
      </div>
    </div>
  );
}
