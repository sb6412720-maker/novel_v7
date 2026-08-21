import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import BookCard from "../components/BookCard";
import { getAuthorBooks, getUserProfile } from "../api";

export default function AuthorPage() {
  const { authorId } = useParams();
  const [profile, setProfile] = useState(null);
  const [books, setBooks] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [p, b] = await Promise.all([
          getUserProfile(authorId),
          getAuthorBooks(authorId),
        ]);
        if (!cancelled) {
          setProfile(p);
          setBooks(b?.items || b?.books || []);
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [authorId]);

  const name = profile?.display_name || profile?.username || profile?.author || `Author #${authorId}`;

  return (
    <div className="full-bleed">
      <div className="full-bleed-inner page">
        <div className="author-hero-row">
          <div className="author-avatar lg">{(name || "?")[0]}</div>
          <div>
            <h1>{name}</h1>
            <p className="meta">{books.length} stories on NovelHub</p>
          </div>
        </div>
        {error && <div className="error-banner">{error}</div>}
        <h2 className="section-h">Stories</h2>
        <div className="trending-grid">
          {books.map((b) => (
            <div key={b.id} className="trending-cell">
              <BookCard book={b} variant="grid" />
            </div>
          ))}
        </div>
        {books.length === 0 && !error && (
          <p className="meta">
            No public stories yet. <Link to="/discover">Discover others</Link>
          </p>
        )}
      </div>
    </div>
  );
}
