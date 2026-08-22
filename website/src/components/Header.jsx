import { useEffect, useRef, useState } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";
import AuthModal from "./AuthModal";

const NAV = [
  { to: "/discover", label: "Free Books" },
  { to: "/audiobooks", label: "Audiobooks", beta: true },
  { to: "/write", label: "Write", dropdown: true },
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
  const [writeOpen, setWriteOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const writeRef = useRef(null);
  const searchRef = useRef(null);
  const navigate = useNavigate();
  const isGuest =
    !user ||
    String(user.email || "").includes("guest") ||
    String(user.provider || "") === "guest";

  const initial = String(user?.display_name || user?.email || "S")
    .trim()
    .charAt(0)
    .toUpperCase();

  useEffect(() => {
    function onDoc(e) {
      if (writeRef.current && !writeRef.current.contains(e.target)) setWriteOpen(false);
      if (searchRef.current && !searchRef.current.contains(e.target)) setSearchOpen(false);
    }
    document.addEventListener("click", onDoc);
    return () => document.removeEventListener("click", onDoc);
  }, []);

  useEffect(() => {
    document.body.classList.toggle("nav-open", menuOpen);
    return () => document.body.classList.remove("nav-open");
  }, [menuOpen]);

  function submitSearch(e) {
    e.preventDefault();
    const term = q.trim();
    setSearchOpen(false);
    setMenuOpen(false);
    navigate(term ? `/discover?q=${encodeURIComponent(term)}` : "/discover");
  }

  function openAuth(mode) {
    setAuthMode(mode);
    setAuthOpen(true);
  }

  return (
    <>
      <header className="site-header site-header--inkitt">
        <div className="header-bar">
          <button
            type="button"
            className="menu-toggle"
            aria-label={menuOpen ? "Close menu" : "Open menu"}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((v) => !v)}
          >
            {menuOpen ? "✕" : "☰"}
          </button>

          <Link to="/" className="logo" onClick={() => setMenuOpen(false)}>
            <span className="logo-word">NovelHub</span>
          </Link>

          <nav className={`nav-links ${menuOpen ? "open" : ""}`} aria-label="Main">
            {NAV.map((item) =>
              item.dropdown ? (
                <div className="nav-dropdown" key={item.to} ref={writeRef}>
                  <button
                    type="button"
                    className={`nav-dropdown-btn ${writeOpen ? "open" : ""}`}
                    onClick={(e) => {
                      e.stopPropagation();
                      setWriteOpen((v) => !v);
                    }}
                  >
                    {item.label}
                  </button>
                  {writeOpen && (
                    <div className="nav-dropdown-menu">
                      <Link
                        to="/write"
                        onClick={() => {
                          setWriteOpen(false);
                          setMenuOpen(false);
                        }}
                      >
                        ✎ Write or Upload Story
                      </Link>
                      <Link
                        to="/audiobooks"
                        onClick={() => {
                          setWriteOpen(false);
                          setMenuOpen(false);
                        }}
                      >
                        🎧 Create Audiobook <span className="badge-beta">Beta</span>
                      </Link>
                      <hr />
                      <Link
                        to="/manage-stories"
                        onClick={() => {
                          setWriteOpen(false);
                          setMenuOpen(false);
                        }}
                      >
                        Manage Stories
                      </Link>
                      <Link
                        to="/contests"
                        onClick={() => {
                          setWriteOpen(false);
                          setMenuOpen(false);
                        }}
                      >
                        Contest Winners
                      </Link>
                    </div>
                  )}
                </div>
              ) : (
                <NavLink
                  key={item.to}
                  to={item.to}
                  onClick={() => setMenuOpen(false)}
                  className={({ isActive }) => (isActive ? "active" : undefined)}
                >
                  {item.label}
                  {item.beta ? <span className="badge-beta">Beta</span> : null}
                </NavLink>
              )
            )}
            {/* Mobile-only account links */}
            <div className="nav-mobile-account">
              {isGuest ? (
                <>
                  <button type="button" className="btn-text" onClick={() => openAuth("signin")}>
                    Sign in
                  </button>
                  <button type="button" className="btn-signup" onClick={() => openAuth("signup")}>
                    Sign up
                  </button>
                </>
              ) : (
                <>
                  <Link to="/library" onClick={() => setMenuOpen(false)}>
                    Library
                  </Link>
                  <Link to="/manage-stories" onClick={() => setMenuOpen(false)}>
                    My Stories
                  </Link>
                  <button type="button" className="btn-text" onClick={onLogout}>
                    Sign out
                  </button>
                </>
              )}
            </div>
          </nav>

          <div className="header-actions header-actions--inkitt">
            <div className={`search-wrap ${searchOpen ? "open" : ""}`} ref={searchRef}>
              <button
                type="button"
                className="icon-btn"
                aria-label="Search"
                onClick={(e) => {
                  e.stopPropagation();
                  setSearchOpen((v) => !v);
                }}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="11" cy="11" r="7" />
                  <path d="M20 20l-3.5-3.5" />
                </svg>
              </button>
              {searchOpen && (
                <form className="search-popover" onSubmit={submitSearch}>
                  <input
                    autoFocus
                    value={q}
                    onChange={(e) => setQ(e.target.value)}
                    placeholder="Search stories"
                    aria-label="Search stories"
                  />
                  <button type="submit" className="btn btn-primary btn-sm">
                    Go
                  </button>
                </form>
              )}
            </div>

            <button type="button" className="icon-btn lang-btn" title="Language">
              EN
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                <path d="M7 10l5 5 5-5z" />
              </svg>
            </button>

            <button type="button" className="icon-btn" aria-label="Notifications" title="Notifications">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M18 16v-5a6 6 0 10-12 0v5l-2 2h16l-2-2z" />
                <path d="M9 18a3 3 0 006 0" />
              </svg>
            </button>

            {isGuest ? (
              <div className="header-auth-desktop">
                <button type="button" className="btn-text" onClick={() => openAuth("signin")}>
                  SIGN IN
                </button>
                <button type="button" className="btn-signup" onClick={() => openAuth("signup")}>
                  SIGN UP
                </button>
              </div>
            ) : (
              <div className="header-user-desktop">
                <Link to="/library" className="btn-text desktop-only">
                  Library
                </Link>
                <button
                  type="button"
                  className="avatar-btn"
                  title={user?.display_name || user?.email || "Account"}
                  onClick={() => navigate("/manage-stories")}
                >
                  <span className="avatar-circle">{initial}</span>
                </button>
              </div>
            )}
          </div>
        </div>
      </header>
      {menuOpen && (
        <button
          type="button"
          className="nav-backdrop"
          aria-label="Close menu"
          onClick={() => setMenuOpen(false)}
        />
      )}
      <AuthModal
        open={authOpen}
        mode={authMode}
        onClose={() => setAuthOpen(false)}
        onSuccess={async (token, res) => {
          await onAuthSuccess?.(token, res);
          setAuthOpen(false);
          navigate("/", { replace: true });
        }}
      />
    </>
  );
}
