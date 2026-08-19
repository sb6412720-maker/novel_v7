import { useState } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";

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
          <NavLink to="/discover" onClick={() => setMenuOpen(false)}>
            Free Books
          </NavLink>
          <span className="nav-item muted" title="Coming soon">
            Audiobooks <span className="badge-beta">Beta</span>
          </span>
          <NavLink to="/write" onClick={() => setMenuOpen(false)}>
            Write
          </NavLink>
          <span className="nav-item muted">Community</span>
          <span className="nav-item muted">Galatea</span>
          <span className="nav-item muted">Writing Contests</span>
          <span className="nav-item muted">Author Subscription</span>
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
