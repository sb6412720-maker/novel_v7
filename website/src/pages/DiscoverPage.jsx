import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
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

export default function DiscoverPage() {
  const [params] = useSearchParams();
  const q = (params.get("q") || "").trim().toLowerCase();
  const genre = (params.get("genre") || "").trim().toLowerCase();
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const boot = await getBootstrap();
        if (!cancelled) setBooks(collectBooks(boot));
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = useMemo(() => {
    return books.filter((b) => {
      const hay = `${b.title || ""} ${b.author || ""} ${b.genre || ""} ${b.description || ""}`.toLowerCase();
      if (q && !hay.includes(q)) return false;
      if (genre && !(b.genre || "").toLowerCase().includes(genre) && !(b.primary_genre || "").toLowerCase().includes(genre)) {
        // soft match: allow if no genre on book
        if (b.genre || b.primary_genre) return false;
      }
      return true;
    });
  }, [books, q, genre]);

  return (
    <div className="container page">
      <header className="page-header">
        <h1>Discover</h1>
        <p className="meta">
          {genre ? `Genre: ${params.get("genre")}` : "All stories"}
          {q ? ` · Search: “${params.get("q")}”` : ""}
          {" · "}
          {filtered.length} results
        </p>
      </header>
      {loading && <p className="meta">Loading…</p>}
      {error && <div className="error-banner">{error}</div>}
      <div className="book-grid">
        {filtered.map((b) => (
          <BookCard key={b.id} book={b} />
        ))}
      </div>
      {!loading && filtered.length === 0 && <p className="meta">No stories match.</p>}
    </div>
  );
}
