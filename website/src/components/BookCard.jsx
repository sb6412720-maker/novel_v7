import { Link } from "react-router-dom";
import { resolveAssetUrl } from "../api";

export default function BookCard({ book, variant = "shelf", link = true }) {
  if (!book) return null;
  const cover = resolveAssetUrl(book.cover_path || book.coverPath || "");
  const rating = book.rating != null ? Number(book.rating).toFixed(1) : null;
  const tag = book.secondary_genre || book.genre || book.primary_genre || "";
  const to = `/stories/${book.id}`;
  const className = `book-card book-card--${variant}`;

  const body = (
    <>
      <div className="book-cover-wrap">
        {rating != null && !Number.isNaN(rating) && variant !== "mini" && (
          <span className="rating-badge">
            <span className="star">★</span> {rating}
          </span>
        )}
        {cover ? (
          <img className="book-cover" src={cover} alt="" loading="lazy" />
        ) : (
          <div
            className="book-cover book-cover--fallback"
            style={{ background: book.accent_hex || "#1f2937" }}
          >
            <span className="fallback-letter">{(book.title || "?")[0]}</span>
          </div>
        )}
      </div>
      {variant !== "mini" && (
        <div className="book-meta">
          <div className="book-title">{book.title}</div>
          <div className="book-author">by {book.author || "Unknown"}</div>
          {tag && variant === "shelf" ? <span className="book-tag-chip">{tag}</span> : null}
        </div>
      )}
    </>
  );

  if (!link) {
    return <div className={className}>{body}</div>;
  }
  return (
    <Link to={to} className={className}>
      {body}
    </Link>
  );
}
