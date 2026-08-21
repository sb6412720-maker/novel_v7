import { useState } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";

const NAV = [
  { to: "/discover", label: "Free Books", real: true },
  { to: "/audiobooks", label: "Audiobooks", real: true, beta: true },
  { to: "/write", label: "Write", real: true },
  { to: "/community", label: "Community", real: true },
  { to: "/galatea", label: "Galatea", real: true },
  { to: "/contests", label: "Writing Contests", real: true },
  { to: "/subscription", label: "Author Subscription", real: true },
];

export default function Header({ user, onLogout }) {
  const [q, setQ] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const navigate = useNavigate();
  const isGuest =
    !user ||
    String(user.email || "").includes("guest") ||
    String(user.provider || "") === "guest";

  function submitSearch(e) {
    e.preventDefault();
    const term = q.trim();
    navigate(term ? `/discover?q=${encodeURIComponent(term)}` : "/discover");
    setMenuOpen(false);
  }

  return (
    <header className="site-header">
      <div className="header-bar">
        <button
          type="button"
          className="nav-toggle"
          aria-label="Menu"
          onClick={() => setMenuOpen((v) => !v)}
        >
          ☰
        </button>

        <Link to="/" className="logo" onClick={() => setMenuOpen(false)}>
          <span className="logo-word">NovelHub</span>
        </Link>

        <nav className={`nav-links ${menuOpen ? "open" : ""}`}>
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) => (isActive ? "active" : undefined)}
            >
              {item.label}
              {item.beta ? <span className="badge-beta">Beta</span> : null}
            </NavLink>
          ))}
        </nav>

        <div className="header-actions">
          <form className="search-box" onSubmit={submitSearch}>
            <button type="submit" className="search-icon-btn" aria-label="Search">
              ⌕
            </button>
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search"
              aria-label="Search stories"
            />
          </form>
          <button type="button" className="lang-btn" title="Language">
            EN ▾
          </button>
          {isGuest ? (
            <>
              <Link className="btn-text" to="/login">
                SIGN IN
              </Link>
              <Link className="btn-signup" to="/login">
                SIGN UP
              </Link>
            </>
          ) : (
            <>
              <Link className="btn-text" to="/library">
                Library
              </Link>
              <span className="user-chip" title={user.email || ""}>
                {user.display_name || user.email}
              </span>
              <button type="button" className="btn-text" onClick={onLogout}>
                SIGN OUT
              </button>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
