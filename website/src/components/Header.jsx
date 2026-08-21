import { useState } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";
import AuthModal from "./AuthModal";

const NAV = [
  { to: "/discover", label: "Free Books" },
  { to: "/audiobooks", label: "Audiobooks", beta: true },
  { to: "/write", label: "Write" },
  { to: "/community", label: "Community" },
  { to: "/galatea", label: "Galatea" },
  { to: "/contests", label: "Writing Contests" },
  { to: "/subscription", label: "Author Subscription" },
];

export default function Header({ user, onLogout, onAuthSuccess }) {
  const [q, setQ] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const [authOpen, setAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState("signin");
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

  function openAuth(mode) {
    setAuthMode(mode);
    setAuthOpen(true);
  }

  return (
    <>
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
                <button type="button" className="btn-text" onClick={() => openAuth("signin")}>
                  SIGN IN
                </button>
                <button type="button" className="btn-signup" onClick={() => openAuth("signup")}>
                  SIGN UP
                </button>
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
      <AuthModal
        open={authOpen}
        mode={authMode}
        onClose={() => setAuthOpen(false)}
        onSuccess={async (token, res) => {
          await onAuthSuccess?.(token, res);
        }}
      />
    </>
  );
}
