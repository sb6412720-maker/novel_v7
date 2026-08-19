import { Link } from "react-router-dom";
import { resolveAssetUrl } from "../api";

export default function BookCard({ book }) {
  if (!book) return null;
  const title = book.title || "Untitled";
  const author = book.author || "Unknown";
  const genre = book.genre || book.primary_genre || book.primaryGenre || "";
  const rating = Number(book.rating || 0);
  const cover = resolveAssetUrl(book.cover_path || book.coverPath || "");

  return (
    <Link to={`/stories/${book.id}`} className="book-card">
      <div className="book-cover-wrap">
        {cover ? (
          <img src={cover} alt="" className="book-cover" loading="lazy" />
        ) : (
          <div
            className="book-cover book-cover--fallback"
            style={{ background: book.accent_hex || book.accentHex || "#1f2937" }}
          >
            <span>{title.slice(0, 1)}</span>
          </div>
        )}
        {rating > 0 && (
          <span className="book-rating">
            <span className="star">★</span> {rating.toFixed(1)}
          </span>
        )}
      </div>
      <div className="book-meta">
        <h3 className="book-title">{title}</h3>
        <p className="book-author">by {author}</p>
        {genre ? <p className="book-genre">{genre}</p> : null}
      </div>
    </Link>
  );
}
