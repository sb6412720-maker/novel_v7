import { useRef, useState, useEffect } from "react";
import { Link } from "react-router-dom";
import BookCard from "./BookCard";

export default function Shelf({ title, books = [], seeAllTo }) {
  const scroller = useRef(null);
  const [canLeft, setCanLeft] = useState(false);
  const [canRight, setCanRight] = useState(true);

  function updateArrows() {
    const el = scroller.current;
    if (!el) return;
    setCanLeft(el.scrollLeft > 8);
    setCanRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 8);
  }

  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    updateArrows();
    el.addEventListener("scroll", updateArrows, { passive: true });
    window.addEventListener("resize", updateArrows);
    return () => {
      el.removeEventListener("scroll", updateArrows);
      window.removeEventListener("resize", updateArrows);
    };
  }, [books]);

  function scroll(dir) {
    const el = scroller.current;
    if (!el) return;
    el.scrollBy({ left: dir * Math.min(el.clientWidth * 0.85, 560), behavior: "smooth" });
  }

  if (!books.length) return null;

  return (
    <section className="shelf full-bleed">
      <div className="full-bleed-inner">
        <div className="shelf-header">
          <h2>{title}</h2>
          <div className="shelf-actions">
            {seeAllTo ? (
              <Link to={seeAllTo} className="see-all">
                See all
              </Link>
            ) : null}
            <button
              type="button"
              className="shelf-nav"
              onClick={() => scroll(-1)}
              aria-label="Previous"
              disabled={!canLeft}
              style={{ opacity: canLeft ? 1 : 0.35 }}
            >
              ‹
            </button>
            <button
              type="button"
              className="shelf-nav"
              onClick={() => scroll(1)}
              aria-label="Next"
              disabled={!canRight}
              style={{ opacity: canRight ? 1 : 0.35 }}
            >
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
      </div>
    </section>
  );
}
