import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import BookCard from "../components/BookCard";
import Shelf from "../components/Shelf";
import { getAudiobooks } from "../api";

export default function AudiobooksPage() {
  const [books, setBooks] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await getAudiobooks();
        if (!cancelled) setBooks(res?.items || []);
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

  return (
    <div className="audiobooks-page">
      <section className="audiobook-hero">
        <div className="audiobook-hero-inner">
          <div className="ab-icon">🎧</div>
          <h1>hello AUDIOBOOKS</h1>
          <p className="lead">The stories you love, now with a voice.</p>
          <p className="meta">From addictive romance to epic fantasies — featured from the same MySQL catalog.</p>
        </div>
      </section>

      {loading && <div className="container page">Loading…</div>}
      {error && <div className="container page error-banner">{error}</div>}

      {!loading && (
        <>
          <Shelf title="Featured Audiobooks" books={books.slice(0, 16)} seeAllTo="/discover" />
          <div className="container page">
            <h2>All listenables</h2>
            <div className="audiobook-grid">
              {books.map((b) => (
                <div key={b.id} className="ab-card-wrap">
                  <BookCard book={b} variant="shelf" />
                  <Link className="btn btn-primary ab-listen" to={`/stories/${b.id}`}>
                    ▶ Listen / Read
                  </Link>
                </div>
              ))}
              {!books.length && (
                <p className="meta">No featured books yet — run backend seed and ensure covers exist in /uploads.</p>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
