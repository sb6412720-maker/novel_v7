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
  const writeRef = useRef(null);
  const navigate = useNavigate();
  const isGuest =
    !user ||
    String(user.email || "").includes("guest") ||
    String(user.provider || "") === "guest";

  useEffect(() => {
    function onDoc(e) {
      if (writeRef.current && !writeRef.current.contains(e.target)) {
        setWriteOpen(false);
      }
    }
    document.addEventListener("click", onDoc);
    return () => document.removeEventListener("click", onDoc);
  }, []);

  function submitSearch(e) {
    e.preventDefault();
    const term = q.trim();
    navigate(term ? `/discover?q=${encodeURIComponent(term)}` : "/discover");
  }

  function openAuth(mode) {
    setAuthMode(mode);
    setAuthOpen(true);
  }

  return (
    <>
      <header className="site-header">
        <div className="header-inner">
          <button
            type="button"
            className="menu-toggle"
            aria-label="Menu"
            onClick={() => setMenuOpen((v) => !v)}
          >
            ☰
          </button>

          <Link to="/" className="logo" onClick={() => setMenuOpen(false)}>
            <span className="logo-word">NovelHub</span>
          </Link>

          <nav className={`nav-links ${menuOpen ? "open" : ""}`}>
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
                    {item.label} ▾
                  </button>
                  {writeOpen && (
                    <div className="nav-dropdown-menu">
                      <Link to="/write" onClick={() => { setWriteOpen(false); setMenuOpen(false); }}>
                        ✎ Write or Upload Story
                      </Link>
                      <Link to="/audiobooks" onClick={() => { setWriteOpen(false); setMenuOpen(false); }}>
                        🎧 Create Audiobook <span className="badge-beta">Beta</span>
                      </Link>
                      <hr />
                      <Link to="/manage-stories" onClick={() => { setWriteOpen(false); setMenuOpen(false); }}>
                        Manage Stories
                      </Link>
                      <Link to="/contests" onClick={() => { setWriteOpen(false); setMenuOpen(false); }}>
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
                <Link className="btn-text" to="/manage-stories">
                  My Stories
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
          setAuthOpen(false);
          navigate("/", { replace: true });
        }}
      />
    </>
  );
}
