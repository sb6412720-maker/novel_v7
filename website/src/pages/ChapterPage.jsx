import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getBook, getBookChapters, getChapter } from "../api";

export default function ChapterPage() {
  const { id, chapterId } = useParams();
  const [book, setBook] = useState(null);
  const [chapter, setChapter] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [b, ch, listRes] = await Promise.all([
          getBook(id),
          getChapter(id, chapterId),
          getBookChapters(id),
        ]);
        if (!cancelled) {
          setBook(b);
          setChapter(ch);
          setChapters(listRes?.items || []);
        }
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id, chapterId]);

  if (error) return <div className="container page error-banner">{error}</div>;
  if (!chapter) return <div className="container page">Loading chapter…</div>;

  const idx = chapters.findIndex((c) => String(c.id) === String(chapterId));
  const prev = idx > 0 ? chapters[idx - 1] : null;
  const next = idx >= 0 && idx < chapters.length - 1 ? chapters[idx + 1] : null;
  const paragraphs = String(chapter.content || "")
    .split(/\n\n+/)
    .map((p) => p.trim())
    .filter(Boolean);

  return (
    <div className="container reader-page">
      <div className="reader-top">
        <Link to={`/stories/${id}`} className="back-link">
          ← {book?.title || "Story"}
        </Link>
        <h1>{chapter.title || "Chapter"}</h1>
      </div>
      <article className="reader-body">
        {paragraphs.length ? (
          paragraphs.map((p, i) => <p key={i}>{p}</p>)
        ) : (
          <p className="meta">Empty chapter.</p>
        )}
      </article>
      <div className="reader-nav">
        {prev ? (
          <Link className="btn" to={`/stories/${id}/chapters/${prev.id}`}>
            ← Previous
          </Link>
        ) : (
          <span />
        )}
        {next ? (
          <Link className="btn btn-primary" to={`/stories/${id}/chapters/${next.id}`}>
            Next →
          </Link>
        ) : (
          <Link className="btn" to={`/stories/${id}`}>
            Back to story
          </Link>
        )}
      </div>
    </div>
  );
}
