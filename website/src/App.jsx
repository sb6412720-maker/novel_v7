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
import StoryEditorPage from "./pages/StoryEditorPage";
import GenrePage from "./pages/GenrePage";
import ContestsPage from "./pages/ContestsPage";
import CommunityPage from "./pages/CommunityPage";
import AuthorPage from "./pages/AuthorPage";
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
    if (token) setToken(token);
    await refreshUser();
  }

  return (
    <div className="app-shell">
      <Header user={user} onLogout={handleLogout} onAuthSuccess={handleLoginSuccess} />
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
            <Route path="/authors/:authorId" element={<AuthorPage />} />
            <Route path="/library" element={<LibraryPage user={user} />} />
            <Route path="/write" element={<WritePage user={user} />} />
            <Route path="/write/stories/:storyId" element={<StoryEditorPage user={user} />} />
            <Route path="/login" element={<LoginPage onSuccess={handleLoginSuccess} />} />
            <Route path="/community" element={<CommunityPage user={user} />} />
            <Route path="/contests" element={<ContestsPage user={user} />} />
            <Route
              path="/audiobooks"
              element={
                <PlaceholderPage
                  title="Audiobooks"
                  blurb="Beta — same story catalog; audio files can attach later via uploads API."
                />
              }
            />
            <Route
              path="/galatea"
              element={
                <PlaceholderPage
                  title="Galatea"
                  blurb="Premium reading partner page placeholder (Inkitt → Galatea)."
                />
              }
            />
            <Route
              path="/subscription"
              element={
                <PlaceholderPage
                  title="Author Subscription"
                  blurb="Subscription program placeholder — billing can integrate later."
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
