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
    const err = new Error(typeof msg === "string" ? msg : JSON.stringify(msg));
    err.status = res.status;
    throw err;
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
    body: JSON.stringify({ device_id: `web-${crypto.randomUUID?.() || Date.now()}` }),
  });
}

export function emailLogin(email, password) {
  return request("/api/auth/email", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export function getBook(id) {
  return request(`/api/books/${id}`);
}

/** Chapters include full content from this list endpoint */
export function getBookChapters(storyId) {
  return request(`/api/write/stories/${storyId}/chapters`);
}

export async function getChapter(storyId, chapterId) {
  const res = await getBookChapters(storyId);
  const items = res?.items || [];
  const found = items.find((c) => String(c.id) === String(chapterId));
  if (!found) throw new Error("Chapter not found");
  return found;
}

export function getBookReviews(bookId) {
  return request(`/api/books/${bookId}/reviews`).catch(() => ({ items: [] }));
}

export function getLibrary() {
  return request("/api/library");
}

export function getReadingLists() {
  return request("/api/reading-lists");
}

/** Ensure a default list exists, then add the book */
export async function addToReadingList(bookId) {
  const lists = await getReadingLists();
  const items = lists?.items || lists || [];
  let listId = items[0]?.id;
  if (!listId) {
    const created = await request("/api/reading-lists", {
      method: "POST",
      body: JSON.stringify({ name: "Reading List", story_count: 0, sort_order: 0 }),
    });
    listId = created?.id;
  }
  if (!listId) throw new Error("Could not create reading list");
  return request(`/api/reading-lists/${listId}/items`, {
    method: "POST",
    body: JSON.stringify({ book_id: Number(bookId) }),
  });
}

export function likeBook(bookId) {
  return request(`/api/books/${bookId}/like`, { method: "POST", body: "{}" });
}

export function unlikeBook(bookId) {
  return request(`/api/books/${bookId}/like`, { method: "DELETE" });
}

export function getBookLike(bookId) {
  return request(`/api/books/${bookId}/like`);
}

export function getMyStories() {
  return request("/api/write/stories").catch(() => ({ items: [] }));
}

export function searchStories(q, genre) {
  const params = new URLSearchParams();
  if (q) params.set("q", q);
  if (genre) params.set("genre", genre);
  return request(`/api/search?${params.toString()}`);
}

export function getAuthorBooks(authorId) {
  return request(`/api/authors/${authorId}/books`).catch(() => ({ items: [] }));
}

export function getUserProfile(userId) {
  return request(`/api/users/${userId}`).catch(() => null);
}

export function getTags() {
  return request("/api/tags").catch(() => ({ items: [] }));
}

export function getWriteStory(storyId) {
  return request(`/api/write/stories/${storyId}`);
}

export function createStory(payload) {
  return request("/api/write/stories", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateStory(storyId, payload) {
  return request(`/api/write/stories/${storyId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deleteStory(storyId) {
  return request(`/api/write/stories/${storyId}`, { method: "DELETE" });
}

export function createChapter(storyId, payload) {
  return request(`/api/write/stories/${storyId}/chapters`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateChapter(chapterId, payload) {
  return request(`/api/write/chapters/${chapterId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deleteChapter(chapterId) {
  return request(`/api/write/chapters/${chapterId}`, { method: "DELETE" });
}
