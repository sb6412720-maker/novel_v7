import { useEffect, useState } from "react";
import BookCard from "../components/BookCard";
import { getLibrary } from "../api";

export default function LibraryPage({ user }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [tab, setTab] = useState("ongoing");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const lib = await getLibrary();
        if (!cancelled) setData(lib);
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user]);

  const ongoing = data?.ongoing || data?.items?.filter?.((x) => x.reading_status === "Reading") || [];
  const completed =
    data?.completed || data?.items?.filter?.((x) => x.reading_status === "Completed") || [];
  const readingList = data?.reading_list || data?.lists?.[0]?.books || [];

  const list =
    tab === "completed" ? completed : tab === "list" ? readingList : ongoing;

  return (
    <div className="container page">
      <header className="page-header">
        <h1>Library</h1>
        <p className="meta">Synced from the same database as the mobile app.</p>
      </header>
      <div className="tabs">
        {[
          ["ongoing", "Ongoing"],
          ["completed", "Completed"],
          ["list", "Reading list"],
        ].map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={`tab ${tab === id ? "active" : ""}`}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
      </div>
      {error && <div className="error-banner">{error}</div>}
      <div className="book-grid">
        {(list || []).map((b) => (
          <BookCard key={b.id || b.book_id} book={b.book || b} />
        ))}
      </div>
      {!error && (list || []).length === 0 && (
        <p className="meta">Nothing here yet. Open a story in the app or on web to track progress.</p>
      )}
    </div>
  );
}
