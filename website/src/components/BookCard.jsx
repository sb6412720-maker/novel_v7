import { Link } from "react-router-dom";
import { resolveAssetUrl } from "../api";

/**
 * Inkitt-style story card.
 * variant: "grid" (trending / discover) | "shelf" (horizontal rail)
 */
export default function BookCard({ book, variant = "grid" }) {
  if (!book) return null;
  const title = book.title || "Untitled";
  const author = book.author || "Unknown";
  const genre = book.genre || book.primary_genre || book.primaryGenre || "";
  const rating = Number(book.rating || 0);
  const cover = resolveAssetUrl(book.cover_path || book.coverPath || "");
  const accent = book.accent_hex || book.accentHex || "#2d3748";

  return (
    <Link
      to={`/stories/${book.id}`}
      className={`book-card book-card--${variant}`}
    >
      <div className="book-cover-wrap">
        {cover ? (
          <img
            src={cover}
            alt=""
            className="book-cover"
            loading="lazy"
            onError={(e) => {
              e.currentTarget.style.display = "none";
              const fb = e.currentTarget.nextElementSibling;
              if (fb) fb.style.display = "grid";
            }}
          />
        ) : null}
        <div
          className="book-cover book-cover--fallback"
          style={{
            background: `linear-gradient(160deg, ${accent} 0%, #111 100%)`,
            display: cover ? "none" : "grid",
          }}
        >
          <span className="fallback-letter">{title.slice(0, 1).toUpperCase()}</span>
          <span className="fallback-title">{title}</span>
        </div>

        {/* Inkitt-style rating badge — top left on cover */}
        {rating > 0 && (
          <span className="book-rating-badge" aria-label={`Rated ${rating.toFixed(1)}`}>
            <svg className="rating-star" viewBox="0 0 24 24" width="11" height="11" aria-hidden>
              <path
                fill="currentColor"
                d="M12 2l2.9 6.9L22 10.3l-5 4.6 1.4 7.1L12 18.3 5.6 22l1.4-7.1-5-4.6 7.1-1.4L12 2z"
              />
            </svg>
            <span className="rating-num">{rating.toFixed(1)}</span>
          </span>
        )}
      </div>

      <div className="book-meta">
        <h3 className="book-title">{title}</h3>
        <p className="book-author">
          by <span className="author-name">{author}</span>
        </p>
        {genre ? <p className="book-genre">{genre}</p> : null}
      </div>
    </Link>
  );
}
