const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000").replace(/\/$/, "");

const TOKEN_KEY = "novelhub_web_token";

export { API_BASE_URL };

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

export function setToken(token) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export function resolveAssetUrl(path) {
  if (!path) return "";
  if (path.startsWith("http://") || path.startsWith("https://") || path.startsWith("data:")) {
    return path;
  }
  const p = path.startsWith("/") ? path : `/${path}`;
  return `${API_BASE_URL}${p}`;
}

async function request(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (!(options.body instanceof FormData)) {
    headers["Content-Type"] = headers["Content-Type"] || "application/json";
  }
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });

  if (!res.ok) {
    let msg = `Request failed (${res.status})`;
    try {
      const data = await res.json();
      msg = data.detail || data.message || msg;
      if (Array.isArray(msg)) msg = msg.map((m) => m.msg || JSON.stringify(m)).join(", ");
    } catch {
      try {
        msg = (await res.text()) || msg;
      } catch {
        /* ignore */
      }
    }
    throw new Error(typeof msg === "string" ? msg : JSON.stringify(msg));
  }
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export function getBootstrap() {
  return request("/api/bootstrap");
}

export function getMe() {
  return request("/api/me");
}

export function guestLogin() {
  return request("/api/auth/guest", {
    method: "POST",
    body: JSON.stringify({ device_id: `web-${Date.now()}` }),
  });
}

export function emailLogin(email, password) {
  return request("/api/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  }).catch(() =>
    request("/api/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    })
  );
}

export function getBook(id) {
  return request(`/api/books/${id}`).catch(() =>
    getBootstrap().then((b) => {
      const books = [
        ...(b?.books || []),
        ...(b?.recently_updated || []),
        ...(b?.recently_completed || []),
        ...(b?.featured || []),
      ];
      const found = books.find((x) => String(x.id) === String(id));
      if (!found) throw new Error("Story not found");
      return found;
    })
  );
}

export function getBookChapters(storyId) {
  return request(`/api/write/stories/${storyId}/chapters`).catch(() =>
    request(`/api/stories/${storyId}/chapters`).catch(() => ({ items: [] }))
  );
}

export function getChapter(chapterId) {
  return request(`/api/write/chapters/${chapterId}`).catch(() =>
    request(`/api/chapters/${chapterId}`)
  );
}

export function getBookReviews(bookId) {
  return request(`/api/books/${bookId}/reviews`).catch(() => ({ items: [] }));
}

export function getLibrary() {
  return request("/api/library").catch(() =>
    request("/api/library/ongoing").catch(() => ({ items: [], ongoing: [], completed: [], reading_list: [] }))
  );
}

export function addToReadingList(bookId) {
  return request("/api/library/reading-list", {
    method: "POST",
    body: JSON.stringify({ book_id: bookId }),
  }).catch(() =>
    request(`/api/library/reading-list/${bookId}`, { method: "POST", body: "{}" })
  );
}

export function likeBook(bookId) {
  return request(`/api/books/${bookId}/like`, { method: "POST", body: "{}" }).catch(() =>
    request(`/api/stories/${bookId}/like`, { method: "POST", body: "{}" })
  );
}

export function getMyStories() {
  return request("/api/write/stories").catch(() => ({ items: [] }));
}
