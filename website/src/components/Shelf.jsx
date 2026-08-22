import { useRef, useState, useEffect } from "react";
import { Link } from "react-router-dom";
import BookCard from "./BookCard";

export default function Shelf({ title, books = [], seeAllTo, seeAllLabel = "View All →" }) {
  const scroller = useRef(null);
  const [canLeft, setCanLeft] = useState(false);
  const [canRight, setCanRight] = useState(true);

  function updateArrows() {
    const el = scroller.current;
    if (!el) return;
    setCanLeft(el.scrollLeft > 4);
    setCanRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 4);
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
    const step = Math.min(el.clientWidth * 0.8, 640);
    el.scrollBy({ left: dir * step, behavior: "smooth" });
  }

  if (!books.length) return null;

  return (
    <section className="shelf shelf--inkitt">
      <div className="shelf-inner">
        <div className="shelf-header">
          <h2>{title}</h2>
          <div className="shelf-actions">
            {seeAllTo ? (
              <Link to={seeAllTo} className="see-all">
                {seeAllLabel}
              </Link>
            ) : null}
          </div>
        </div>
        <div className="shelf-track-wrap">
          {canLeft && (
            <button type="button" className="shelf-arrow shelf-arrow--left" onClick={() => scroll(-1)} aria-label="Previous">
              ‹
            </button>
          )}
          <div className="shelf-track" ref={scroller}>
            {books.map((b) => (
              <div key={b.id} className="shelf-item">
                <BookCard book={b} variant="shelf" />
              </div>
            ))}
          </div>
          {canRight && (
            <button type="button" className="shelf-arrow shelf-arrow--right" onClick={() => scroll(1)} aria-label="Next">
              ›
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
