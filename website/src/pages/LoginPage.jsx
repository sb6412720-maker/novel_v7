import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { emailLogin, guestLogin, setToken, getMe } from "../api";

export default function LoginPage({ onSuccess }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const navigate = useNavigate();

  async function finish(token) {
    setToken(token);
    try {
      await onSuccess?.(token);
    } catch {
      /* still navigate — token is set */
    }
    // Force leave login page
    navigate("/", { replace: true });
  }

  async function onSubmit(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const res = await emailLogin(email.trim(), password);
      const token = res?.access_token || res?.token || res?.accessToken;
      if (!token) throw new Error("No token returned — check email/password");
      await finish(token);
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setBusy(false);
    }
  }

  async function asGuest() {
    setBusy(true);
    setError("");
    try {
      const res = await guestLogin();
      const token = res?.access_token || res?.token;
      if (!token) throw new Error("Guest login failed");
      await finish(token);
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="container page narrow">
      <h1>Sign in</h1>
      <p className="meta">Same auth as the mobile app and admin panel.</p>
      <form className="auth-form" onSubmit={onSubmit}>
        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
          />
        </label>
        {error && <div className="error-banner">{error}</div>}
        <button type="submit" className="btn btn-primary" disabled={busy}>
          {busy ? "Signing in…" : "Sign in"}
        </button>
        <button type="button" className="btn" disabled={busy} onClick={asGuest}>
          Continue as guest
        </button>
      </form>
    </div>
  );
}
