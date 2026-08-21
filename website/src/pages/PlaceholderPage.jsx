import { Link } from "react-router-dom";

export default function PlaceholderPage({ title, blurb }) {
  return (
    <div className="full-bleed">
      <div className="full-bleed-inner page">
        <h1 style={{ fontFamily: "var(--serif)", fontSize: "2rem" }}>{title}</h1>
        <p className="meta" style={{ maxWidth: 520 }}>
          {blurb ||
            "This section mirrors Inkitt’s navigation. Content can be wired to your backend when ready."}
        </p>
        <Link className="btn btn-primary" to="/discover" style={{ marginTop: 16 }}>
          Browse Free Books
        </Link>
      </div>
    </div>
  );
}
