import { useEffect, useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import BookCard from "../components/BookCard";
import { getBootstrap, searchStories } from "../api";

const GENRES = [
  "Romance",
  "Fantasy",
  "Thriller",
  "Young Adult",
  "LGBTQ+",
  "Sci-Fi",
  "Drama",
  "Adventure",
  "Mystery",
  "Horror",
];

function collectBooks(data) {
  if (!data) return [];
  const map = new Map();
  for (const list of [data.books, data.recently_updated, data.recently_completed, data.featured, data.trending]) {
    if (!Array.isArray(list)) continue;
    for (const b of list) {
      if (b?.id != null && !map.has(b.id)) map.set(b.id, b);
    }
  }
  return [...map.values()];
}

export default function DiscoverPage() {
  const [params, setParams] = useSearchParams();
  const q = (params.get("q") || "").trim();
  const genre = (params.get("genre") || "").trim();
  const status = (params.get("status") || "all").toLowerCase();
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [localQ, setLocalQ] = useState(q);

  useEffect(() => {
    setLocalQ(q);
  }, [q]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError("");
      try {
        let list = [];
        if (q || genre) {
          try {
            const res = await searchStories(q, genre);
            list = res?.items || res?.books || res || [];
            if (!Array.isArray(list)) list = [];
          } catch {
            const boot = await getBootstrap();
            list = collectBooks(boot);
          }
        } else {
          const boot = await getBootstrap();
          list = collectBooks(boot);
        }
        if (!cancelled) setBooks(list);
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [q, genre]);

  const filtered = useMemo(() => {
    return books.filter((b) => {
      const st = (b.status_text || b.status || "").toLowerCase();
      if (status === "complete" && !/complete|publish|finished/.test(st) && st) {
        // allow empty status
        if (st && !/complete|finished|publish/.test(st)) return false;
      }
      if (status === "ongoing" && /complete|finished/.test(st)) return false;
      if (genre) {
        const g = `${b.genre || ""} ${b.primary_genre || ""}`.toLowerCase();
        if (g && !g.includes(genre.toLowerCase())) return false;
      }
      if (q) {
        const hay = `${b.title || ""} ${b.author || ""} ${b.genre || ""} ${b.description || ""}`.toLowerCase();
        if (!hay.includes(q.toLowerCase())) return false;
      }
      return true;
    });
  }, [books, status, genre, q]);

  function setFilter(key, value) {
    const next = new URLSearchParams(params);
    if (!value || value === "all") next.delete(key);
    else next.set(key, value);
    setParams(next);
  }

  function onSearch(e) {
    e.preventDefault();
    setFilter("q", localQ.trim());
  }

  return (
    <div className="full-bleed discover-page">
      <div className="full-bleed-inner">
        <header className="page-header discover-header">
          <h1>Free Books</h1>
          <p className="meta">
            Same catalog as the mobile app · MySQL backend · {filtered.length} stories
          </p>
        </header>

        <form className="discover-search" onSubmit={onSearch}>
          <input
            value={localQ}
            onChange={(e) => setLocalQ(e.target.value)}
            placeholder="Search title, author, genre…"
            aria-label="Search free books"
          />
          <button type="submit" className="btn btn-primary">
            Search
          </button>
        </form>

        <div className="discover-filters">
          <div className="filter-row">
            <span className="filter-label">Status</span>
            {[
              ["all", "All"],
              ["complete", "Complete"],
              ["ongoing", "Ongoing"],
            ].map(([id, label]) => (
              <button
                key={id}
                type="button"
                className={`chip ${status === id ? "active" : ""}`}
                onClick={() => setFilter("status", id)}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="filter-row filter-genres">
            <span className="filter-label">Genre</span>
            <button
              type="button"
              className={`chip ${!genre ? "active" : ""}`}
              onClick={() => setFilter("genre", "")}
            >
              All
            </button>
            {GENRES.map((g) => (
              <button
                key={g}
                type="button"
                className={`chip ${genre.toLowerCase() === g.toLowerCase() ? "active" : ""}`}
                onClick={() => setFilter("genre", g)}
              >
                {g}
              </button>
            ))}
          </div>
        </div>

        {loading && <p className="meta">Loading stories…</p>}
        {error && <div className="error-banner">{error}</div>}

        <div className="trending-grid discover-grid">
          {filtered.map((b) => (
            <div key={b.id} className="trending-cell">
              <BookCard book={b} variant="grid" />
            </div>
          ))}
        </div>
        {!loading && filtered.length === 0 && (
          <p className="meta">
            No stories match. Try another genre or{" "}
            <Link to="/discover">clear filters</Link>.
          </p>
        )}
      </div>
    </div>
  );
}
