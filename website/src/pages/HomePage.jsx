import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import BookCard from "../components/BookCard";
import PhoneMockup from "../components/PhoneMockup";
import Shelf from "../components/Shelf";
import { getBootstrap, getReadingLists } from "../api";

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
    return fields.some((f) => f.includes(g) || g.includes(f));
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
    <>
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
                  onClick={() => navigate(g === "More" ? "/discover" : `/genres/${encodeURIComponent(g)}`)}
                >
                  {g}
                </button>
              ))}
            </div>
          </div>
          <PhoneMockup />
        </div>
      </section>

      {/* Promo banner like Inkitt */}
      <div className="promo-banner">
        <div className="promo-banner-inner">
          <span className="promo-icon">☎</span>
          <div>
            <strong>Tell us how we’re doing.</strong>
            <span> Get a $20 Gift Card</span>
          </div>
          <Link className="btn btn-promo" to="/login">
            SIGN UP
          </Link>
        </div>
      </div>

      <section className="contest-neon">
        <div className="contest-neon-inner">
          <h2 className="neon-title">LOVE IN<br />FULL COLOR</h2>
          <div className="neon-copy">
            <p className="neon-kicker">WRITING CONTEST 2026</p>
            <p>Every kind of love, every kind of story.</p>
            <Link className="btn btn-neon" to="/contests">
              ENTER NOW
            </Link>
          </div>
        </div>
      </section>

      <div className="home-shelves">
        <Shelf title="Trending Stories" books={trending} seeAllTo="/discover" />

        {/* Reading lists row (public showcase) */}
        <section className="shelf reading-lists-shelf">
          <div className="shelf-head">
            <h2>Reading Lists</h2>
          </div>
          <div className="shelf-track reading-list-track">
            {[
              { name: "Finished Reading", by: "PhoenixWerewolf", n: 13 },
              { name: "Completed", by: "I'm_just_here", n: 10 },
              { name: "Heart Breaking", by: "Jasmine N", n: 8 },
              { name: "Mafia", by: "Anjola", n: 11 },
              { name: "Favs", by: "abcya", n: 39 },
              { name: "Vampire", by: "Gillian", n: 10 },
            ].map((rl) => (
              <div key={rl.name} className="reading-list-card">
                <div className="rl-covers">
                  {trending.slice(0, 3).map((b) => (
                    <div key={b.id} className="rl-cover-thumb">
                      <BookCard book={b} variant="mini" />
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
        </section>

        {GENRE_SHELVES.map((genre) => {
          let books = byGenre(allBooks, genre);
          if (books.length < 4) {
            // pad from trending so shelves never look empty
            const ids = new Set(books.map((b) => b.id));
            for (const b of trending) {
              if (books.length >= 10) break;
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

        <section className="shelf fandoms-shelf">
          <div className="shelf-head">
            <h2>Fandoms</h2>
            <Link className="see-all" to="/discover">
              View All →
            </Link>
          </div>
          <div className="fandoms-track">
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
                    <BookCard key={`${f.name}-${b.id}`} book={b} variant="mini" />
                  ))}
                </div>
                <h3>{f.name}</h3>
                <p className="meta">{f.n} stories</p>
              </Link>
            ))}
          </div>
        </section>

        <section className="shelf">
          <div className="shelf-head">
            <h2>Top Reviews</h2>
          </div>
          <div className="top-reviews-row">
            {trending.slice(0, 5).map((b) => (
              <Link key={b.id} to={`/stories/${b.id}`} className="top-review-card">
                <BookCard book={b} variant="mini" />
                <div className="top-review-body">
                  <div className="stars">{"★".repeat(Math.round(Number(b.rating) || 5))}</div>
                  <strong>{b.title}</strong>
                  <p className="meta">by {b.author}</p>
                  <p className="review-snippet">
                    {(b.description || "A captivating read from start to finish.").slice(0, 120)}…
                  </p>
                </div>
              </Link>
            ))}
          </div>
        </section>
      </div>
    </>
  );
}
