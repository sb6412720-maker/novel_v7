import { useCallback, useEffect, useState } from "react";
import { Route, Routes } from "react-router-dom";
import Header from "./components/Header";
import Footer from "./components/Footer";
import HomePage from "./pages/HomePage";
import DiscoverPage from "./pages/DiscoverPage";
import StoryPage from "./pages/StoryPage";
import ChapterPage from "./pages/ChapterPage";
import LibraryPage from "./pages/LibraryPage";
import LoginPage from "./pages/LoginPage";
import WritePage from "./pages/WritePage";
import GenrePage from "./pages/GenrePage";
import PlaceholderPage from "./pages/PlaceholderPage";
import { getMe, guestLogin, setToken, getToken, clearToken } from "./api";

export default function App() {
  const [user, setUser] = useState(null);
  const [bootLoading, setBootLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    if (!getToken()) {
      setUser(null);
      return null;
    }
    try {
      const me = await getMe();
      setUser(me);
      return me;
    } catch {
      clearToken();
      setUser(null);
      return null;
    }
  }, []);

  useEffect(() => {
    (async () => {
      try {
        if (!getToken()) {
          try {
            const g = await guestLogin();
            const token = g?.access_token || g?.token;
            if (token) setToken(token);
          } catch {
            /* optional */
          }
        }
        await refreshUser();
      } finally {
        setBootLoading(false);
      }
    })();
  }, [refreshUser]);

  function handleLogout() {
    clearToken();
    setUser(null);
  }

  async function handleLoginSuccess(token) {
    setToken(token);
    await refreshUser();
  }

  return (
    <div className="app-shell">
      <Header user={user} onLogout={handleLogout} />
      <main className="main">
        {bootLoading ? (
          <div className="page-loading">Loading…</div>
        ) : (
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/discover" element={<DiscoverPage />} />
            <Route path="/genres/:genre" element={<GenrePage />} />
            <Route path="/stories/:id" element={<StoryPage user={user} />} />
            <Route path="/stories/:id/chapters/:chapterId" element={<ChapterPage user={user} />} />
            <Route path="/library" element={<LibraryPage user={user} />} />
            <Route path="/write" element={<WritePage user={user} />} />
            <Route path="/login" element={<LoginPage onSuccess={handleLoginSuccess} />} />
            <Route
              path="/audiobooks"
              element={
                <PlaceholderPage
                  title="Audiobooks"
                  blurb="Listen to stories — Beta. Wire audio assets when ready; same catalog as Free Books."
                />
              }
            />
            <Route
              path="/community"
              element={
                <PlaceholderPage
                  title="Community"
                  blurb="Forums and newsfeed can connect to your activity/wall APIs next."
                />
              }
            />
            <Route
              path="/galatea"
              element={
                <PlaceholderPage
                  title="Galatea"
                  blurb="Partner / premium reading experience placeholder (Inkitt’s Galatea link)."
                />
              }
            />
            <Route
              path="/contests"
              element={
                <PlaceholderPage
                  title="Writing Contests"
                  blurb="Contest listings can be driven from admin notifications or a contests table."
                />
              }
            />
            <Route
              path="/subscription"
              element={
                <PlaceholderPage
                  title="Author Subscription"
                  blurb="Subscription author program placeholder — monetization hooks later."
                />
              }
            />
          </Routes>
        )}
      </main>
      <Footer />
    </div>
  );
}
