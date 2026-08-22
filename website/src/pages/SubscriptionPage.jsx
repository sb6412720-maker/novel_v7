import { Link } from "react-router-dom";

export default function SubscriptionPage({ user }) {
  return (
    <div className="container page subscription-page">
      <h1>Author Subscription</h1>
      <p className="lead">
        Support authors you love. Subscription billing is not connected yet — stories and chapters
        already live in the shared MySQL database used by the mobile app and admin panel.
      </p>
      <div className="card-panel">
        <h2>What you can do today</h2>
        <ul>
          <li>
            <Link to="/write">Write & publish stories</Link> for free
          </li>
          <li>
            <Link to="/manage-stories">Manage your stories</Link>
          </li>
          <li>
            Follow authors from any <Link to="/discover">story page</Link>
          </li>
        </ul>
        <p className="meta">
          Signed in as: {user?.display_name || user?.email || "Guest"}
        </p>
        <p className="meta">
          When you add Stripe (or similar), this page can list tiers and checkout — the catalog APIs
          stay the same.
        </p>
      </div>
    </div>
  );
}
