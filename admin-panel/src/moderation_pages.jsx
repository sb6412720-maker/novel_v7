import { useCallback, useEffect, useMemo, useState } from "react";
import {
  API_BASE_URL,
  listAdminUsers,
  banUser,
  unbanUser,
  suspendUser,
  unsuspendUser,
  activateUser,
  deleteAdminUser,
  restoreUser,
  setAuthorActive,
  fetchUserActivity,
} from "./api";

function asArray(v) {
  return Array.isArray(v) ? v : [];
}

function coverUrl(path) {
  if (!path) return "";
  if (path.startsWith("http")) return path;
  const base = API_BASE_URL.replace(/\/$/, "");
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
}

/** Derive one canonical status from DB flags (priority: deleted > banned > suspended > inactive > active) */
function userStatus(u) {
  if (!u) return "Active";
  if (u.is_deleted) return "Deleted";
  if (u.is_banned) return "Banned";
  if (u.is_suspended) return "Suspended";
  if (u.is_author_active === false) return "Inactive";
  return "Active";
}

function statusClass(status) {
  const s = (status || "").toLowerCase();
  if (s === "active") return "st-active";
  if (s === "banned") return "st-banned";
  if (s === "suspended") return "st-suspended";
  if (s === "deleted") return "st-deleted";
  if (s === "inactive") return "st-inactive";
  return "st-active";
}

function StatusPill({ status }) {
  return (
    <span className={`status-pill ${statusClass(status)}`}>
      <span className="status-dot" />
      {status}
    </span>
  );
}

async function runUserAction(id, action) {
  if (action === "ban") return banUser(id);
  if (action === "unban") return unbanUser(id);
  if (action === "suspend") {
    const raw = window.prompt("Suspend for how many days?", "7");
    if (raw === null) return null;
    const days = Math.max(1, parseInt(raw, 10) || 7);
    return suspendUser(id, days);
  }
  if (action === "unsuspend") return unsuspendUser(id);
  if (action === "activate") return activateUser(id);
  if (action === "delete") return deleteAdminUser(id);
  if (action === "restore") return restoreUser(id);
  if (action === "active") return setAuthorActive(id, true);
  if (action === "inactive") return setAuthorActive(id, false);
  throw new Error(`Unknown action: ${action}`);
}

/** Optimistic local patch so Status column + buttons flip immediately */
function localPatchForAction(action) {
  if (action === "ban") return { is_banned: true, is_suspended: false };
  if (action === "unban") return { is_banned: false };
  if (action === "suspend") return { is_suspended: true };
  if (action === "unsuspend") return { is_suspended: false, suspended_until: null };
  if (action === "activate") return { is_banned: false, is_suspended: false, suspended_until: null };
  if (action === "delete") return { is_deleted: true };
  if (action === "restore")
    return {
      is_deleted: false,
      is_banned: false,
      is_suspended: false,
      suspended_until: null,
      is_author_active: true,
    };
  if (action === "active") return { is_author_active: true };
  if (action === "inactive") return { is_author_active: false };
  return {};
}

const ACTION_LABELS = {
  ban: "Banned — button is now Unban",
  unban: "Unbanned — button is now Ban",
  suspend: "Suspended — button is now Unsuspend",
  unsuspend: "Unsuspended",
  activate: "Fully activated",
  delete: "Deleted — Recover available",
  restore: "Recovered — full access restored",
  active: "Author marked Active",
  inactive: "Author marked Inactive",
};

/* ───────── Attractive account view modal ───────── */
export function AccountViewModal({ user, roleLabel, onClose, onAction, busy }) {
  const [activity, setActivity] = useState([]);
  const [actLoading, setActLoading] = useState(false);
  const [actError, setActError] = useState("");

  useEffect(() => {
    if (!user?.id) return;
    let cancelled = false;
    (async () => {
      setActLoading(true);
      setActError("");
      try {
        const data = await fetchUserActivity(user.id);
        if (!cancelled) setActivity(asArray(data?.items ?? data));
      } catch (e) {
        if (!cancelled) {
          setActError(String(e.message || e));
          setActivity([]);
        }
      } finally {
        if (!cancelled) setActLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user?.id]);

  if (!user) return null;
  const status = userStatus(user);
  const initial = (user.display_name || user.email || "?").charAt(0).toUpperCase();
  const deleted = status === "Deleted";
  const banned = status === "Banned";
  const suspended = status === "Suspended";
  const inactive = status === "Inactive";

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal account-view-modal pro-view" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 720, maxHeight: "90vh", overflow: "auto" }}>
        <div className="pro-view-hero">
          <div className="pro-view-hero-bg" />
          <button type="button" className="pro-view-close" onClick={onClose} aria-label="Close">
            ×
          </button>
          <div className="pro-view-avatar-wrap">
            {user.photo_url ? (
              <img src={coverUrl(user.photo_url)} alt="" className="pro-view-avatar" />
            ) : (
              <div className="pro-view-avatar pro-view-avatar-fallback">{initial}</div>
            )}
            <StatusPill status={status} />
          </div>
          <h2 className="pro-view-name">{user.display_name || "Unnamed"}</h2>
          <p className="pro-view-email">{user.email || "—"}</p>
          <div className="pro-view-meta-row">
            <span className="pro-chip">{roleLabel}</span>
            <span className="pro-chip">{user.is_author ? "Author" : "Reader"}</span>
            <span className="pro-chip muted">{user.provider || "local"}</span>
            <span className="pro-chip muted">#{user.id}</span>
          </div>
        </div>

        <div className="pro-view-stats">
          <div className="pro-stat">
            <div className="pro-stat-value">{user.story_count ?? 0}</div>
            <div className="pro-stat-label">Stories</div>
          </div>
          <div className="pro-stat">
            <div className="pro-stat-value">{user.followers ?? 0}</div>
            <div className="pro-stat-label">Followers</div>
          </div>
          <div className="pro-stat">
            <div className="pro-stat-value">{status === "Active" ? "Yes" : "No"}</div>
            <div className="pro-stat-label">Can login</div>
          </div>
        </div>

        <div className="pro-view-fields" style={{ padding: "12px 16px" }}>
          <h3 style={{ margin: "8px 0" }}>Account details (live from DB)</h3>
          <div className="pro-field"><span className="pro-field-label">User ID</span><p className="pro-field-value">{user.id}</p></div>
          <div className="pro-field"><span className="pro-field-label">Email</span><p className="pro-field-value">{user.email || "—"}</p></div>
          <div className="pro-field"><span className="pro-field-label">Display name</span><p className="pro-field-value">{user.display_name || "—"}</p></div>
          <div className="pro-field"><span className="pro-field-label">Provider</span><p className="pro-field-value">{user.provider || "—"}</p></div>
          <div className="pro-field"><span className="pro-field-label">Bio</span><p className="pro-field-value">{user.bio || "—"}</p></div>
          <div className="pro-field"><span className="pro-field-label">is_banned</span><p className="pro-field-value">{String(!!user.is_banned)}</p></div>
          <div className="pro-field"><span className="pro-field-label">is_suspended</span><p className="pro-field-value">{String(!!user.is_suspended)}</p></div>
          <div className="pro-field"><span className="pro-field-label">is_deleted</span><p className="pro-field-value">{String(!!user.is_deleted)}</p></div>
          {user.suspended_until ? (
            <div className="pro-field"><span className="pro-field-label">Suspended until</span><p className="pro-field-value">{String(user.suspended_until)}</p></div>
          ) : null}
        </div>

        <div style={{ padding: "8px 16px 16px" }}>
          <h3 style={{ margin: "8px 0" }}>Activity</h3>
          {actLoading && <p className="meta">Loading activity…</p>}
          {actError && <p className="error-banner">{actError}</p>}
          {!actLoading && activity.length === 0 && <p className="meta">No recent activity.</p>}
          <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
            {activity.map((a) => (
              <li key={a.id || `${a.type}-${a.created_at}`} style={{ padding: "8px 0", borderBottom: "1px solid rgba(255,255,255,0.08)" }}>
                <strong>{a.title || a.type}</strong>
                <div className="meta">{a.message || ""}</div>
                <div className="meta">{a.created_at || ""}</div>
              </li>
            ))}
          </ul>
        </div>

        <div className="pro-view-actions" style={{ flexWrap: "wrap", gap: 8, padding: 16 }}>
          {!deleted && (
            banned ? (
              <button type="button" className="btn btn-success" disabled={busy} onClick={() => onAction?.(user, "unban")}>{busy ? "…" : "Unban"}</button>
            ) : (
              <button type="button" className="btn btn-danger" disabled={busy} onClick={() => onAction?.(user, "ban")}>{busy ? "…" : "Ban"}</button>
            )
          )}
          {!deleted && !banned && (
            suspended ? (
              <button type="button" className="btn btn-success" disabled={busy} onClick={() => onAction?.(user, "unsuspend")}>{busy ? "…" : "Unsuspend"}</button>
            ) : (
              <button type="button" className="btn btn-warn" disabled={busy} onClick={() => onAction?.(user, "suspend")}>{busy ? "…" : "Suspend"}</button>
            )
          )}
          {deleted ? (
            <button type="button" className="btn btn-success" disabled={busy} onClick={() => onAction?.(user, "restore")}>{busy ? "…" : "Recover"}</button>
          ) : (
            <button type="button" className="btn btn-danger" disabled={busy} onClick={() => onAction?.(user, "delete")}>{busy ? "…" : "Delete"}</button>
          )}
          <button type="button" className="btn btn-ghost" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

/* ───────── Shared action buttons for a row ───────── */
function RowActions({ row, busyId, onView, onAct }) {
  const status = userStatus(row);
  const deleted = status === "Deleted";
  const banned = status === "Banned";
  const suspended = status === "Suspended";
  const busy = busyId === row.id;

  // Default: View, Ban, Suspend, Delete — each swaps to its inverse after action
  return (
    <div className="btn-row" style={{ flexWrap: "wrap", gap: 6 }}>
      <button type="button" className="btn btn-sm btn-ghost" disabled={busy} onClick={() => onView(row)}>
        {busy ? "…" : "View"}
      </button>
      {!deleted && (
        banned ? (
          <button type="button" className="btn btn-sm btn-success" disabled={busy} onClick={() => onAct(row, "unban")}>
            {busy ? "…" : "Unban"}
          </button>
        ) : (
          <button type="button" className="btn btn-sm btn-danger" disabled={busy} onClick={() => onAct(row, "ban")}>
            {busy ? "…" : "Ban"}
          </button>
        )
      )}
      {!deleted && !banned && (
        suspended ? (
          <button type="button" className="btn btn-sm btn-success" disabled={busy} onClick={() => onAct(row, "unsuspend")}>
            {busy ? "…" : "Unsuspend"}
          </button>
        ) : (
          <button type="button" className="btn btn-sm btn-warn" disabled={busy} onClick={() => onAct(row, "suspend")}>
            {busy ? "…" : "Suspend"}
          </button>
        )
      )}
      {deleted ? (
        <button type="button" className="btn btn-sm btn-success" disabled={busy} onClick={() => onAct(row, "restore")}>
          {busy ? "…" : "Recover"}
        </button>
      ) : (
        <button type="button" className="btn btn-sm btn-danger" disabled={busy} onClick={() => onAct(row, "delete")}>
          {busy ? "…" : "Delete"}
        </button>
      )}
    </div>
  );
}

/* ───────── Authors page ───────── */
export function AuthorsPage({ authors: _authorsProp, search }) {
  const [users, setUsers] = useState([]);
  const [busyId, setBusyId] = useState(null);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [q, setQ] = useState(search || "");
  const [viewUser, setViewUser] = useState(null);
  const [filterStatus, setFilterStatus] = useState("all");
  const [selected, setSelected] = useState(() => new Set());

  const load = useCallback(async () => {
    try {
      setError("");
      const data = await listAdminUsers();
      const all = asArray(data?.items ?? data);
      setUsers(all.filter((u) => u.is_author || (u.story_count || 0) > 0));
      setSelected(new Set());
    } catch (e) {
      setError(String(e.message || e));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    setQ(search || "");
  }, [search]);

  const patchLocal = (id, patch) => {
    setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, ...patch } : u)));
    setViewUser((v) => (v && v.id === id ? { ...v, ...patch } : v));
  };

  const act = async (row, action) => {
    const id = row.id;
    if (action === "delete") {
      if (!window.confirm("Soft-delete this author? They cannot log in. You can recover later.")) return;
    }
    setBusyId(id);
    setError("");
    setSuccess("");
    try {
      const res = await runUserAction(id, action);
      if (res === null) {
        // cancelled (e.g. suspend days prompt) — still clear busy in finally
        return;
      }
      // Prefer live flags from API response (DB truth), fall back to local patch
      const fromApi = {};
      if (res && typeof res === "object") {
        if ("is_banned" in res) fromApi.is_banned = !!res.is_banned;
        if ("is_suspended" in res) fromApi.is_suspended = !!res.is_suspended;
        if ("is_deleted" in res) fromApi.is_deleted = !!res.is_deleted;
        if ("suspended_until" in res) fromApi.suspended_until = res.suspended_until;
        if ("is_author_active" in res) fromApi.is_author_active = !!res.is_author_active;
      }
      patchLocal(id, { ...localPatchForAction(action), ...fromApi });
      setSuccess(`Author #${id}: ${ACTION_LABELS[action] || action}`);
      // Confirm from DB
      await load();
    } catch (e) {
      setError(String(e.message || e));
      await load();
    } finally {
      setBusyId(null);
    }
  };

  const list = useMemo(() => {
    return users.filter((u) => {
      const s = (q || "").trim().toLowerCase();
      if (s) {
        const hay = `${u.display_name || ""} ${u.email || ""} ${u.id}`.toLowerCase();
        if (!hay.includes(s)) return false;
      }
      const st = userStatus(u);
      if (filterStatus === "all") return true;
      return st.toLowerCase() === filterStatus;
    });
  }, [users, q, filterStatus]);

  const allIds = list.map((u) => u.id);
  const allSelected = allIds.length > 0 && allIds.every((id) => selected.has(id));
  const someSelected = selected.size > 0;

  const toggleOne = (id) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleAll = () => {
    if (allSelected) setSelected(new Set());
    else setSelected(new Set(allIds));
  };

  const bulkAct = async (action) => {
    const ids = [...selected];
    if (!ids.length) return;
    if (action === "delete") {
      if (!window.confirm(`Soft-delete ${ids.length} author(s)? Recoverable later.`)) return;
    }
    setBulkBusy(true);
    setError("");
    setSuccess("");
    let ok = 0;
    let fail = 0;
    for (const id of ids) {
      try {
        const res = await runUserAction(id, action);
        if (res === null) continue;
        patchLocal(id, localPatchForAction(action));
        ok += 1;
      } catch {
        fail += 1;
      }
    }
    setSuccess(`Bulk ${action}: ${ok} updated${fail ? `, ${fail} failed` : ""}`);
    setSelected(new Set());
    await load();
    setBulkBusy(false);
  };

  return (
    <div className="layout-with-aside">
      <div className="panel">
        <div className="panel-header">
          <h3>Authors Management</h3>
          <span className="meta">{list.length} authors · live from database</span>
        </div>
        <div className="toolbar">
          <input className="search-input" placeholder="Search name or email…" value={q} onChange={(e) => setQ(e.target.value)} />
          <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)}>
            <option value="all">All statuses</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="banned">Banned</option>
            <option value="suspended">Suspended</option>
            <option value="deleted">Deleted</option>
          </select>
          <button type="button" className="btn btn-sm btn-primary" onClick={load}>
            Refresh
          </button>
        </div>
        {someSelected ? (
          <div className="bulk-bar">
            <span className="meta">{selected.size} selected</span>
            <button type="button" className="btn btn-sm btn-danger" disabled={bulkBusy} onClick={() => bulkAct("ban")}>Ban</button>
            <button type="button" className="btn btn-sm btn-success" disabled={bulkBusy} onClick={() => bulkAct("unban")}>Unban</button>
            <button type="button" className="btn btn-sm btn-warn" disabled={bulkBusy} onClick={() => bulkAct("suspend")}>Suspend</button>
            <button type="button" className="btn btn-sm btn-success" disabled={bulkBusy} onClick={() => bulkAct("unsuspend")}>Unsuspend</button>
            <button type="button" className="btn btn-sm btn-ghost" disabled={bulkBusy} onClick={() => bulkAct("inactive")}>Inactive</button>
            <button type="button" className="btn btn-sm btn-primary" disabled={bulkBusy} onClick={() => bulkAct("active")}>Activate</button>
            <button type="button" className="btn btn-sm btn-danger" disabled={bulkBusy} onClick={() => bulkAct("delete")}>Delete</button>
            <button type="button" className="btn btn-sm btn-success" disabled={bulkBusy} onClick={() => bulkAct("restore")}>Recover</button>
          </div>
        ) : null}
        {error ? <div className="error-banner">{error}</div> : null}
        {success ? <div className="success-banner">{success}</div> : null}
        <div className="table-wrap">
          <table className="data">
            <thead>
              <tr>
                <th style={{ width: 36 }}>
                  <input type="checkbox" checked={allSelected} onChange={toggleAll} title="Select all" />
                </th>
                <th>Profile</th>
                <th>Author</th>
                <th>Email</th>
                <th>Novels</th>
                <th>Followers</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {list.map((a) => {
                const status = userStatus(a);
                return (
                  <tr key={a.id} className={selected.has(a.id) ? "row-selected" : ""}>
                    <td>
                      <input type="checkbox" checked={selected.has(a.id)} onChange={() => toggleOne(a.id)} />
                    </td>
                    <td>
                      <div className="row-profile">
                        {a.photo_url ? (
                          <img src={coverUrl(a.photo_url)} alt="" />
                        ) : (
                          <div className="ph avatar-fallback">{(a.display_name || "?")[0]}</div>
                        )}
                      </div>
                    </td>
                    <td style={{ fontWeight: 600 }}>{a.display_name || "—"}</td>
                    <td className="meta">{a.email || "—"}</td>
                    <td>{a.story_count ?? 0}</td>
                    <td>{a.followers ?? 0}</td>
                    <td>
                      <StatusPill status={status} />
                    </td>
                    <td>
                      <RowActions row={a} busyId={busyId} onView={setViewUser} onAct={act} />
                    </td>
                  </tr>
                );
              })}
              {list.length === 0 && (
                <tr>
                  <td colSpan={8} className="empty">
                    No authors match this filter.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
      {viewUser ? (
        <AccountViewModal
          user={viewUser}
          roleLabel="Author"
          busy={busyId === viewUser.id}
          onClose={() => setViewUser(null)}
          onAction={act}
        />
      ) : null}
    </div>
  );
}

/* ───────── Users page ───────── */
export function UsersPage({ profile, supportRequests, onUpdateSupport }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [viewUser, setViewUser] = useState(null);
  const [filterStatus, setFilterStatus] = useState("all");
  const [selected, setSelected] = useState(() => new Set());

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await listAdminUsers();
      setUsers(asArray(data?.items ?? data));
      setSelected(new Set());
    } catch (e) {
      setError(String(e.message || e));
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const patchLocal = (id, patch) => {
    setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, ...patch } : u)));
    setViewUser((v) => (v && v.id === id ? { ...v, ...patch } : v));
  };

  const runAction = async (row, action) => {
    const id = row.id;
    if (action === "delete") {
      if (!window.confirm("Soft-delete this account? Login blocked until recovered.")) return;
    }
    setBusyId(id);
    setError("");
    setSuccess("");
    try {
      const res = await runUserAction(id, action);
      if (res === null) return;
      const fromApi = {};
      if (res && typeof res === "object") {
        if ("is_banned" in res) fromApi.is_banned = !!res.is_banned;
        if ("is_suspended" in res) fromApi.is_suspended = !!res.is_suspended;
        if ("is_deleted" in res) fromApi.is_deleted = !!res.is_deleted;
        if ("suspended_until" in res) fromApi.suspended_until = res.suspended_until;
        if ("is_author_active" in res) fromApi.is_author_active = !!res.is_author_active;
      }
      patchLocal(id, { ...localPatchForAction(action), ...fromApi });
      setSuccess(`User #${id}: ${ACTION_LABELS[action] || action}`);
      await load();
    } catch (e) {
      setError(String(e.message || e));
      await load();
    } finally {
      setBusyId(null);
    }
  };

  const filtered = useMemo(() => {
    return users.filter((u) => {
      const s = q.trim().toLowerCase();
      if (s) {
        const hay = `${u.display_name || ""} ${u.email || ""} ${u.id}`.toLowerCase();
        if (!hay.includes(s)) return false;
      }
      const st = userStatus(u);
      if (filterStatus === "all") return true;
      return st.toLowerCase() === filterStatus;
    });
  }, [users, q, filterStatus]);

  const allIds = filtered.map((u) => u.id);
  const allSelected = allIds.length > 0 && allIds.every((id) => selected.has(id));
  const someSelected = selected.size > 0;

  const toggleOne = (id) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleAll = () => {
    if (allSelected) setSelected(new Set());
    else setSelected(new Set(allIds));
  };

  const bulkAct = async (action) => {
    const ids = [...selected];
    if (!ids.length) return;
    if (action === "delete") {
      if (!window.confirm(`Soft-delete ${ids.length} account(s)?`)) return;
    }
    setBulkBusy(true);
    setError("");
    setSuccess("");
    let ok = 0;
    let fail = 0;
    for (const id of ids) {
      try {
        const res = await runUserAction(id, action);
        if (res === null) continue;
        patchLocal(id, localPatchForAction(action));
        ok += 1;
      } catch {
        fail += 1;
      }
    }
    setSuccess(`Bulk ${action}: ${ok} updated${fail ? `, ${fail} failed` : ""}`);
    setSelected(new Set());
    await load();
    setBulkBusy(false);
  };

  return (
    <div className="layout-with-aside">
      <div className="panel">
        <div className="panel-header">
          <h3>Users Management</h3>
          <span className="meta">{filtered.length} users · live from database</span>
        </div>
        <div className="toolbar">
          <input className="search-input" placeholder="Search name, email, id…" value={q} onChange={(e) => setQ(e.target.value)} />
          <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)}>
            <option value="all">All statuses</option>
            <option value="active">Active</option>
            <option value="banned">Banned</option>
            <option value="suspended">Suspended</option>
            <option value="deleted">Deleted</option>
          </select>
          <button type="button" className="btn btn-sm btn-primary" onClick={load}>
            Refresh
          </button>
        </div>
        {someSelected ? (
          <div className="bulk-bar">
            <span className="meta">{selected.size} selected</span>
            <button type="button" className="btn btn-sm btn-danger" disabled={bulkBusy} onClick={() => bulkAct("ban")}>Ban</button>
            <button type="button" className="btn btn-sm btn-success" disabled={bulkBusy} onClick={() => bulkAct("unban")}>Unban</button>
            <button type="button" className="btn btn-sm btn-warn" disabled={bulkBusy} onClick={() => bulkAct("suspend")}>Suspend</button>
            <button type="button" className="btn btn-sm btn-success" disabled={bulkBusy} onClick={() => bulkAct("unsuspend")}>Unsuspend</button>
            <button type="button" className="btn btn-sm btn-primary" disabled={bulkBusy} onClick={() => bulkAct("activate")}>Activate</button>
            <button type="button" className="btn btn-sm btn-danger" disabled={bulkBusy} onClick={() => bulkAct("delete")}>Delete</button>
            <button type="button" className="btn btn-sm btn-success" disabled={bulkBusy} onClick={() => bulkAct("restore")}>Recover</button>
          </div>
        ) : null}
        {error ? <div className="error-banner">{error}</div> : null}
        {success ? <div className="success-banner">{success}</div> : null}
        <div className="table-wrap">
          <table className="data">
            <thead>
              <tr>
                <th style={{ width: 36 }}>
                  <input type="checkbox" checked={allSelected} onChange={toggleAll} title="Select all" />
                </th>
                <th>Profile</th>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Stories</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td colSpan={8} className="empty">
                    Loading users from database…
                  </td>
                </tr>
              )}
              {!loading &&
                filtered.map((u) => {
                  const status = userStatus(u);
                  return (
                    <tr key={u.id} className={selected.has(u.id) ? "row-selected" : ""}>
                      <td>
                        <input type="checkbox" checked={selected.has(u.id)} onChange={() => toggleOne(u.id)} />
                      </td>
                      <td>
                        <div className="row-profile">
                          {u.photo_url ? (
                            <img src={coverUrl(u.photo_url)} alt="" />
                          ) : (
                            <div className="ph avatar-fallback">{(u.display_name || "?")[0]}</div>
                          )}
                        </div>
                      </td>
                      <td style={{ fontWeight: 600 }}>{u.display_name || "—"}</td>
                      <td className="meta">{u.email || "—"}</td>
                      <td>{u.is_author ? "Author" : "Reader"}</td>
                      <td>{u.story_count ?? 0}</td>
                      <td>
                        <StatusPill status={status} />
                        {u.suspended_until ? (
                          <div className="meta" style={{ fontSize: ".7rem", marginTop: 4 }}>
                            until {String(u.suspended_until).slice(0, 10)}
                          </div>
                        ) : null}
                      </td>
                      <td>
                        <RowActions row={u} busyId={busyId} onView={setViewUser} onAct={runAction} showAuthorToggle={false} />
                      </td>
                    </tr>
                  );
                })}
              {!loading && filtered.length === 0 && (
                <tr>
                  <td colSpan={8} className="empty">
                    No users found. Profile shell: {profile?.display_name || "—"}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <h3>Support requests</h3>
        </div>
        <div className="table-wrap">
          <table className="data">
            <thead>
              <tr>
                <th>ID</th>
                <th>Subject</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {asArray(supportRequests).map((r) => (
                <tr key={r.id}>
                  <td>{r.id}</td>
                  <td>{r.subject || r.message || "—"}</td>
                  <td>
                    <StatusPill status={r.status || "open"} />
                  </td>
                  <td className="btn-row">
                    <button type="button" className="btn btn-sm" onClick={() => onUpdateSupport?.(r.id, { status: "resolved" })}>
                      Resolve
                    </button>
                    <button type="button" className="btn btn-sm" onClick={() => onUpdateSupport?.(r.id, { status: "closed" })}>
                      Close
                    </button>
                  </td>
                </tr>
              ))}
              {asArray(supportRequests).length === 0 && (
                <tr>
                  <td colSpan={4} className="empty">
                    No support tickets
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {viewUser ? (
        <AccountViewModal
          user={viewUser}
          roleLabel="User"
          busy={busyId === viewUser.id}
          onClose={() => setViewUser(null)}
          onAction={runAction}
        />
      ) : null}
    </div>
  );
}
