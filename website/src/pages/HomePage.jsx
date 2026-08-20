import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import Shelf from "../components/Shelf";
import TrendingGrid from "../components/TrendingGrid";
import { getBootstrap } from "../api";

const GENRE_PILLS = [
  { label: "Romance", color: "#fce7f3" },
  { label: "Fantasy", color: "#ede9fe" },
  { label: "Thriller", color: "#ffedd5" },
  { label: "Young Adult", color: "#d1fae5" },
  { label: "LGBTQ+", color: "#f3e8ff" },
  { label: "Sci-Fi", color: "#d1fae5" },
  { label: "Drama", color: "#e0f2fe" },
  { label: "Adventure", color: "#ffedd5" },
];

function collectBooks(data) {
  if (!data) return [];
  const lists = [
    data.books,
    data.recently_updated,
    data.recently_completed,
    data.featured,
    data.trending,
  ];
  const map = new Map();
  for (const list of lists) {
    if (!Array.isArray(list)) continue;
    for (const b of list) {
      if (b && b.id != null && !map.has(b.id)) map.set(b.id, b);
    }
  }
  // also flatten sections if present
  if (Array.isArray(data.sections)) {
    for (const s of data.sections) {
      for (const b of s.books || []) {
        if (b && b.id != null && !map.has(b.id)) map.set(b.id, b);
      }
    }
  }
  return [...map.values()];
}

export default function HomePage() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError("");
      try {
        const boot = await getBootstrap();
        if (!cancelled) setData(boot);
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

  const allBooks = useMemo(() => collectBooks(data), [data]);

  const trending = useMemo(() => {
    const rated = [...allBooks].sort((a, b) => Number(b.rating || 0) - Number(a.rating || 0));
    return rated.slice(0, 16);
  }, [allBooks]);

  const updated = useMemo(() => {
    if (Array.isArray(data?.recently_updated) && data.recently_updated.length) {
      return data.recently_updated;
    }
    return allBooks.filter((b) => (b.section_name || "") === "recently_updated").slice(0, 16);
  }, [data, allBooks]);

  const completed = useMemo(() => {
    if (Array.isArray(data?.recently_completed) && data.recently_completed.length) {
      return data.recently_completed;
    }
    return allBooks
      .filter(
        (b) =>
          (b.section_name || "") === "recently_completed" ||
          /complete|publish/i.test(b.status_text || "")
      )
      .slice(0, 16);
  }, [data, allBooks]);

  return (
    <>
      <section className="hero inkitt-hero">
        <div className="container">
          <h1>Discover Millions of Free Books</h1>
          <p className="hero-tagline">Our readers are trendsetters.</p>
          <p className="lead">
            Every day, millions of readers come to NovelHub to discover the next bestseller.
          </p>
          <p className="hero-stat">
            <strong>1 in 2 novels</strong> discovered by them become community favorites.
          </p>
          <p className="hero-explore">Explore stories in your favorite genre:</p>
          <div className="genre-pills">
            {GENRE_PILLS.map((g) => (
              <button
                key={g.label}
                type="button"
                className="pill pill-soft"
                style={{ background: g.color }}
                onClick={() => navigate(`/discover?genre=${encodeURIComponent(g.label)}`)}
              >
                {g.label}
              </button>
            ))}
            <button
              type="button"
              className="pill"
              onClick={() => navigate("/discover")}
            >
              More
            </button>
          </div>
          <div className="hero-cta">
            <Link className="btn btn-primary" to="/discover">
              Read Stories
            </Link>
            <Link className="btn btn-outline" to="/write">
              Start Writing
            </Link>
          </div>
        </div>
      </section>

      <div className="container home-body">
        {loading && <p className="meta">Loading stories from your database…</p>}
        {error && (
          <div className="error-banner">
            Could not reach API: {error}. Start the backend and set{" "}
            <code>VITE_API_BASE_URL</code>.
          </div>
        )}
        {!loading && !error && allBooks.length === 0 && (
          <p className="meta">No published stories yet. Seed novels from the admin panel.</p>
        )}

        <TrendingGrid title="Trending Stories" books={trending} seeAllTo="/discover" />
        <Shelf title="Recently Updated" books={updated} seeAllTo="/discover?section=updated" />
        <Shelf title="Completed Stories" books={completed} seeAllTo="/discover?section=completed" />

        <section className="cta-band">
          <h2>Write Your Own Bestseller</h2>
          <p>Your story could be the next big hit. Join a community that discovers tomorrow’s authors today.</p>
          <Link className="btn btn-primary" to="/write">
            Start Writing
          </Link>
        </section>
      </div>
    </>
  );
}
