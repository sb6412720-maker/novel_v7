import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import BookCard from "../components/BookCard";
import PhoneMockup from "../components/PhoneMockup";
import Shelf from "../components/Shelf";
import { getBootstrap } from "../api";

const GENRE_PILLS = [
  "Romance",
  "Fantasy",
  "Thriller",
  "Young Adult",
  "Sci-Fi",
  "LGBTQ+",
  "Mystery",
  "Werewolves",
  "Adventure",
  "More",
];

const GENRE_SHELVES = [
  "Contemporary Romance",
  "Dark Romance",
  "Thriller",
  "Sci-Fi",
  "LGBTQ+",
  "Werewolves & Shifters",
  "Fantasy",
  "Horror",
];

function collectBooks(boot) {
  if (!boot) return [];
  const map = new Map();
  const add = (arr) => {
    (arr || []).forEach((b) => {
      if (b && b.id != null) map.set(String(b.id), b);
    });
  };
  add(boot.books);
  add(boot.trending);
  add(boot.recently_updated);
  add(boot.recently_completed);
  add(boot.featured);
  if (Array.isArray(boot.sections)) {
    boot.sections.forEach((s) => add(s.books || s.items));
  }
  if (boot.categories && typeof boot.categories === "object") {
    Object.values(boot.categories).forEach((v) => {
      if (Array.isArray(v)) add(v);
      else if (v?.books) add(v.books);
    });
  }
  return [...map.values()];
}

function byGenre(books, genre) {
  const g = genre.toLowerCase();
  return books.filter((b) => {
    const fields = [b.genre, b.primary_genre, b.secondary_genre, b.section_name]
      .filter(Boolean)
      .map((x) => String(x).toLowerCase());
    return fields.some((f) => f.includes(g.split(" ")[0]) || g.includes(f) || f.includes(g));
  });
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

  if (loading) return <div className="container page">Loading…</div>;
  if (error) return <div className="container page error-banner">{error}</div>;

  return (
    <div className="home-inkitt">
      <section className="hero inkitt-hero">
        <div className="hero-inner">
          <div className="hero-copy">
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
                  key={g}
                  type="button"
                  className="genre-pill"
                  onClick={() =>
                    navigate(g === "More" ? "/discover" : `/genres/${encodeURIComponent(g)}`)
                  }
                >
                  {g}
                </button>
              ))}
            </div>
          </div>
          <PhoneMockup />
        </div>
      </section>

      <section className="contest-neon">
        <div className="contest-neon-inner">
          <h2 className="neon-title">
            LOVE IN
            <br />
            FULL COLOR
          </h2>
          <div className="neon-copy">
            <p className="neon-kicker">WRITING CONTEST 2026</p>
            <p>Every kind of love, every kind of story.</p>
            <Link className="btn btn-neon" to="/contests">
              ENTER NOW
            </Link>
          </div>
        </div>
      </section>

      <Shelf title="Trending Stories" books={trending} seeAllTo="/discover" />

      {/* Reading Lists */}
      <section className="shelf shelf--inkitt">
        <div className="shelf-inner">
          <div className="shelf-header">
            <h2>Reading Lists</h2>
          </div>
          <div className="shelf-track-wrap">
            <div className="shelf-track reading-list-track">
              {[
                { name: "Finished Reading", by: "PhoenixWerewolf", n: 13 },
                { name: "Heart Breaking", by: "Jasmine N", n: 8 },
                { name: "Mafia", by: "Anjola", n: 11 },
                { name: "Update?", by: "abcya", n: 26 },
                { name: "Mine", by: "Debbie Waters", n: 13 },
                { name: "Fantasy", by: "Therese Simek", n: 10 },
              ].map((rl, i) => (
                <div key={rl.name} className="reading-list-card">
                  <div className="rl-covers-grid">
                    {trending.slice(i % 4, (i % 4) + 4).map((b) => (
                      <div key={`${rl.name}-${b.id}`} className="rl-thumb">
                        <BookCard book={b} variant="mini" link={false} />
                      </div>
                    ))}
                  </div>
                  <h3>{rl.name}</h3>
                  <p className="meta">
                    {rl.n} stories · by {rl.by}
                  </p>
                  <button type="button" className="btn-follow-outline">
                    Follow
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {GENRE_SHELVES.map((genre) => {
        let books = byGenre(allBooks, genre);
        if (books.length < 4) {
          const ids = new Set(books.map((b) => b.id));
          for (const b of trending) {
            if (books.length >= 12) break;
            if (!ids.has(b.id)) {
              books = [...books, b];
              ids.add(b.id);
            }
          }
        }
        if (!books.length) return null;
        return (
          <Shelf
            key={genre}
            title={genre}
            books={books.slice(0, 14)}
            seeAllTo={`/genres/${encodeURIComponent(genre.split(" ")[0])}`}
          />
        );
      })}

      <section className="shelf shelf--inkitt">
        <div className="shelf-inner">
          <div className="shelf-header">
            <h2>Fandoms</h2>
            <Link className="see-all" to="/discover">
              View All →
            </Link>
          </div>
          <div className="shelf-track fandoms-track">
            {[
              { name: "Asian Pop", n: 5191 },
              { name: "Harry Potter", n: 2177 },
              { name: "Marvel Universe", n: 687 },
              { name: "Supernatural", n: 557 },
              { name: "My Hero Academia", n: 545 },
              { name: "Naruto", n: 498 },
              { name: "DC Universe", n: 398 },
            ].map((f) => (
              <Link
                key={f.name}
                className="fandom-card"
                to={`/genres/${encodeURIComponent(f.name)}`}
              >
                <div className="fandom-covers">
                  {trending.slice(0, 4).map((b) => (
                    <BookCard key={`${f.name}-${b.id}`} book={b} variant="mini" link={false} />
                  ))}
                </div>
                <h3>{f.name}</h3>
                <p className="meta">{f.n} stories</p>
              </Link>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
