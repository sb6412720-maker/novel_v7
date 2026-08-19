import { Link } from "react-router-dom";

export default function Footer() {
  return (
    <footer className="site-footer">
      <div className="container footer-grid">
        <div>
          <Link to="/" className="logo footer-logo">
            <span className="logo-word">NovelHub</span>
          </Link>
          <p className="footer-about">
            Reader-powered stories. Discover free novels, follow authors, and write your next
            bestseller — powered by the same backend &amp; database as the mobile app.
          </p>
        </div>
        <div>
          <h4>Explore</h4>
          <Link to="/discover">Discover</Link>
          <Link to="/library">Library</Link>
          <Link to="/write">Start Writing</Link>
        </div>
        <div>
          <h4>Genres</h4>
          <Link to="/discover?genre=Romance">Romance</Link>
          <Link to="/discover?genre=Fantasy">Fantasy</Link>
          <Link to="/discover?genre=Sci-Fi">Sci-Fi</Link>
          <Link to="/discover?genre=Mystery">Mystery</Link>
        </div>
        <div>
          <h4>Account</h4>
          <Link to="/login">Sign in</Link>
        </div>
      </div>
      <div className="container footer-bottom">
        © {new Date().getFullYear()} NovelHub · Same API &amp; database as the mobile app
      </div>
    </footer>
  );
}
