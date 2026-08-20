import { useRef } from "react";
import { Link } from "react-router-dom";
import BookCard from "./BookCard";

export default function Shelf({ title, books = [], seeAllTo }) {
  const scroller = useRef(null);

  function scroll(dir) {
    const el = scroller.current;
    if (!el) return;
    el.scrollBy({ left: dir * Math.min(el.clientWidth * 0.75, 520), behavior: "smooth" });
  }

  if (!books.length) return null;

  return (
    <section className="shelf">
      <div className="shelf-header">
        <h2>{title}</h2>
        <div className="shelf-actions">
          {seeAllTo ? (
            <Link to={seeAllTo} className="see-all">
              See all
            </Link>
          ) : null}
          <button type="button" className="shelf-nav" onClick={() => scroll(-1)} aria-label="Previous">
            ‹
          </button>
          <button type="button" className="shelf-nav" onClick={() => scroll(1)} aria-label="Next">
            ›
          </button>
        </div>
      </div>
      <div className="shelf-track" ref={scroller}>
        {books.map((b) => (
          <div key={b.id} className="shelf-item">
            <BookCard book={b} variant="shelf" />
          </div>
        ))}
      </div>
    </section>
  );
}
