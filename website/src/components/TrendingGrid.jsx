import { Link } from "react-router-dom";
import BookCard from "./BookCard";

/**
 * Inkitt-style "Trending Stories" section — responsive multi-column grid.
 */
export default function TrendingGrid({ title = "Trending Stories", books = [], seeAllTo = "/discover" }) {
  if (!books.length) return null;

  return (
    <section className="trending-section full-bleed">
      <div className="full-bleed-inner">
      <div className="trending-header">
        <h2 className="trending-title">{title}</h2>
        {seeAllTo ? (
          <Link to={seeAllTo} className="trending-see-all">
            See all
          </Link>
        ) : null}
      </div>
      <div className="trending-grid">
        {books.map((b) => (
          <div key={b.id} className="trending-cell">
            <BookCard book={b} variant="grid" />
          </div>
        ))}
      </div>
      </div>
    </section>
  );
}
