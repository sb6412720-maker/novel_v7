import { useEffect } from "react";
import { Link, Navigate } from "react-router-dom";
import { isGuestUser } from "../utils/guest";

/**
 * Inkitt: "Write or Upload Story" opens Manage Stories.
 * This route always redirects there (or login for guests).
 */
export default function WritePage({ user }) {
  const guest = isGuestUser(user);

  if (guest) {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to write</h3>
          <p className="meta">Manage stories and the chapter editor require an account.</p>
          <Link className="btn btn-primary" to="/login">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  return <Navigate to="/manage-stories" replace />;
}
