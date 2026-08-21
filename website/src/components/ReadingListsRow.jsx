import { Link } from "react-router-dom";
import { resolveAssetUrl } from "../api";

/**
 * Build faux reading-list cards from books (grouped) when API lists are empty.
 */
function buildLists(books) {
  if (!books?.length) return [];
  const genres = {};
  for (const b of books) {
    const g = (b.genre || "Mixed").split(/[,/]/)[0].trim() || "Mixed";
    if (!genres[g]) genres[g] = [];
    if (genres[g].length < 4) genres[g].push(b);
  }
  return Object.entries(genres)
    .slice(0, 8)
    .map(([name, items], i) => ({
      id: `genre-${i}`,
      name: `${name} picks`,
      story_count: items.length,
      items,
    }));
}

function ListCard({ list }) {
  const covers = (list.items || list.books || []).slice(0, 3);
  return (
    <Link to={`/discover?genre=${encodeURIComponent((list.name || "").replace(/ picks$/i, ""))}`} className="rl-card">
      <div className="rl-stack">
        {[0, 1, 2].map((i) => {
          const b = covers[i];
          const src = b ? resolveAssetUrl(b.cover_path || b.coverPath || "") : "";
          return (
            <div key={i} className={`rl-cover rl-cover-${i}`}>
              {src ? (
                <img src={src} alt="" />
              ) : (
                <div className="rl-cover-empty" style={{ background: b?.accent_hex || "#cbd5e1" }} />
              )}
            </div>
          );
        })}
      </div>
      <div className="rl-meta">
        <h3 className="rl-name">{list.name}</h3>
        <p className="rl-count">{list.story_count || covers.length} stories</p>
      </div>
    </Link>
  );
}

export default function ReadingListsRow({ lists, books = [] }) {
  const apiLists = Array.isArray(lists) && lists.length ? lists : null;
  const display = apiLists || buildLists(books);
  if (!display.length) return null;

  return (
    <section className="rl-section full-bleed">
      <div className="full-bleed-inner">
      <div className="rl-header">
        <h2 className="rl-title">Reading Lists</h2>
        <Link to="/discover" className="trending-see-all">
          See all
        </Link>
      </div>
      <div className="rl-track">
        {display.map((list) => (
          <ListCard key={list.id || list.name} list={list} />
        ))}
      </div>
      </div>
    </section>
  );
}
