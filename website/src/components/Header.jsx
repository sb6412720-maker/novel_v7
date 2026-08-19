import { useState } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";

export default function Header({ user, onLogout }) {
  const [q, setQ] = useState("");
  const navigate = useNavigate();

  function submitSearch(e) {
    e.preventDefault();
    const term = q.trim();
    navigate(term ? `/discover?q=${encodeURIComponent(term)}` : "/discover");
  }

  return (
    <header className="site-header">
      <div className="container header-inner">
        <Link to="/" className="logo">
          <span className="logo-word">NovelHub</span>
        </Link>
        <nav className="nav-links">
          <NavLink to="/discover">Free Books</NavLink>
          <NavLink to="/write">Write</NavLink>
          <NavLink to="/library">Library</NavLink>
        </nav>
        <div className="header-actions">
          <form className="search-box" onSubmit={submitSearch}>
            <span className="search-icon" aria-hidden>
              ⌕
            </span>
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search"
              aria-label="Search stories"
            />
          </form>
          {user && !String(user.email || "").includes("guest") ? (
            <>
              <span className="user-chip" title={user.email || ""}>
                {user.display_name || user.email || "Reader"}
              </span>
              <button type="button" className="btn btn-ghost btn-sm" onClick={onLogout}>
                Sign out
              </button>
            </>
          ) : (
            <>
              <Link className="btn btn-ghost btn-sm" to="/login">
                SIGN IN
              </Link>
              <Link className="btn btn-primary btn-sm" to="/login">
                SIGN UP
              </Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
