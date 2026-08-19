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
            /* guest optional — public bootstrap still works */
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
            <Route path="/stories/:id" element={<StoryPage />} />
            <Route path="/stories/:id/chapters/:chapterId" element={<ChapterPage />} />
            <Route path="/library" element={<LibraryPage user={user} />} />
            <Route path="/write" element={<WritePage user={user} />} />
            <Route path="/login" element={<LoginPage onSuccess={handleLoginSuccess} />} />
          </Routes>
        )}
      </main>
      <Footer />
    </div>
  );
}
