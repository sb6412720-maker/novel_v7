import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import {
  createChapter,
  createStory,
  deleteChapter,
  getWriteStory,
  resolveAssetUrl,
  updateChapter,
  updateStory,
} from "../api";
import { isGuestUser } from "../utils/guest";

const MIN_PUBLISH_CHARS = 50;

export default function StoryEditorPage({ user }) {
  const { storyId } = useParams();
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const guest = isGuestUser(user);

  const [story, setStory] = useState(null);
  const [chapters, setChapters] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [title, setTitle] = useState("");
  const [storyTitle, setStoryTitle] = useState("");
  const [content, setContent] = useState("");
  const [newChapterName, setNewChapterName] = useState("");
  const [msg, setMsg] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const [lastSaved, setLastSaved] = useState("");
  const [submitOpen, setSubmitOpen] = useState(false);
  const [notesOpen, setNotesOpen] = useState(false);
  const [notes, setNotes] = useState("");
  const [scheduleOpen, setScheduleOpen] = useState(false);
  const [newScheduleOpen, setNewScheduleOpen] = useState(false);
  const [audioView, setAudioView] = useState(search.get("entry") === "audiobook");
  const [scheduleForm, setScheduleForm] = useState({
    name: "",
    interval: "Weekly",
    days: [],
    time: "01:00",
    start: new Date().toISOString().slice(0, 10),
    chapters: "1",
  });
  const [schedules, setSchedules] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(`nh_schedules_${storyId}`) || "[]");
    } catch {
      return [];
    }
  });

  const active = useMemo(
    () => chapters.find((c) => String(c.id) === String(activeId)) || chapters[0],
    [chapters, activeId]
  );

  async function load(id) {
    const res = await getWriteStory(id);
    const s = res?.story || res?.item || res;
    const ch = res?.chapters || res?.items || [];
    setStory(s);
    setStoryTitle(s?.title || "Untitled Story");
    setChapters(Array.isArray(ch) ? ch : []);
    if (ch?.length) {
      const prefer = activeId && ch.find((c) => String(c.id) === String(activeId));
      const pick = prefer || ch[0];
      setActiveId(pick.id);
      setTitle(pick.title || "Chapter 1");
      setContent(pick.content || "");
      setNotes(pick.notes || localStorage.getItem(`nh_notes_${pick.id}`) || "");
    } else {
      // Inkitt creates Chapter 1 automatically for new stories
      try {
        const created = await createChapter(id, {
          title: "Chapter 1",
          content: "",
          chapter_number: 1,
          status_text: "Draft",
        });
        const res2 = await getWriteStory(id);
        const ch2 = res2?.chapters || res2?.items || [];
        setChapters(Array.isArray(ch2) ? ch2 : []);
        const pick = ch2[0] || { id: created?.id || created?.chapter_id, title: "Chapter 1", content: "" };
        setActiveId(pick.id);
        setTitle(pick.title || "Chapter 1");
        setContent(pick.content || "");
        setNotes("");
      } catch (ce) {
        setActiveId(null);
        setTitle("Chapter 1");
        setContent("");
        setMsg(String(ce.message || ce));
      }
    }
  }

  useEffect(() => {
    if (guest) return;
    let cancelled = false;
    (async () => {
      try {
        if (!storyId || storyId === "new") {
          const res = await createStory({
            title: "Untitled Story",
            description: "",
            status_text: "Draft",
            genre: "Romance",
          });
          const id = res?.id || res?.story_id || res?.item?.id;
          if (id && !cancelled) navigate(`/write/${id}`, { replace: true });
          return;
        }
        await load(storyId);
      } catch (e) {
        if (!cancelled) setError(String(e.message || e));
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storyId, guest]);

  function selectChapter(c) {
    setActiveId(c.id);
    setTitle(c.title || "");
    setContent(c.content || "");
    setNotes(c.notes || localStorage.getItem(`nh_notes_${c.id}`) || "");
    setMsg("");
  }

  async function saveChapter() {
    if (!active?.id) {
      setMsg("Create a chapter first");
      return;
    }
    setSaving(true);
    setMsg("");
    try {
      await updateChapter(active.id, { title, content });
      localStorage.setItem(`nh_notes_${active.id}`, notes || "");
      setLastSaved(new Date().toLocaleString());
      setMsg("Saved");
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    } finally {
      setSaving(false);
    }
  }

  async function saveStoryTitle() {
    if (!storyId) return;
    try {
      await updateStory(storyId, { title: storyTitle || "Untitled Story" });
      setMsg("Title updated");
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function addChapter() {
    const name = (newChapterName || `Chapter ${chapters.length + 1}`).trim();
    try {
      const res = await createChapter(storyId, {
        title: name,
        content: "",
        chapter_number: chapters.length + 1,
      });
      setNewChapterName("");
      await load(storyId);
      const id = res?.id || res?.chapter_id;
      if (id) setActiveId(id);
      setMsg("Chapter created");
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function renameChapter(c) {
    const next = window.prompt("Chapter name", c.title || "");
    if (next == null || !next.trim()) return;
    try {
      await updateChapter(c.id, { title: next.trim() });
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function removeChapter(c) {
    if (!window.confirm(`Delete “${c.title}”?`)) return;
    try {
      await deleteChapter(c.id);
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  function canPublish(text) {
    return String(text || "").replace(/\s+/g, " ").trim().length >= MIN_PUBLISH_CHARS;
  }

  async function submitChapter(mode) {
    setSubmitOpen(false);
    if (!active?.id && mode === "one") {
      setMsg("Select a chapter");
      return;
    }
    try {
      if (mode === "one") {
        if (!canPublish(content)) {
          await updateChapter(active.id, {
            title,
            content,
            status_text: "Draft",
          });
          await updateStory(storyId, { status_text: "Draft" });
          setMsg(`Need at least ${MIN_PUBLISH_CHARS} characters to submit — kept as draft`);
        } else {
          await updateChapter(active.id, {
            title,
            content,
            status_text: "Published",
          });
          await updateStory(storyId, { status_text: "Published" });
          setMsg("Chapter submitted");
        }
      } else if (mode === "all") {
        let any = false;
        for (const c of chapters) {
          const body = String(c.id === active?.id ? content : c.content || "");
          if (canPublish(body)) {
            await updateChapter(c.id, {
              title: c.id === active?.id ? title : c.title,
              content: body,
              status_text: "Published",
            });
            any = true;
          } else {
            await updateChapter(c.id, {
              title: c.id === active?.id ? title : c.title,
              content: body,
              status_text: "Draft",
            });
          }
        }
        await updateStory(storyId, { status_text: any ? "Published" : "Draft" });
        setMsg(any ? "Submitted eligible chapters" : "No chapter met 50-character rule — all drafts");
      } else if (mode === "withdraw") {
        for (const c of chapters) {
          await updateChapter(c.id, { status_text: "Draft" });
        }
        await updateStory(storyId, { status_text: "Draft" });
        setMsg("All chapters withdrawn to draft");
      }
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  function saveSchedule() {
    const item = {
      id: Date.now(),
      ...scheduleForm,
    };
    const next = [...schedules, item];
    setSchedules(next);
    localStorage.setItem(`nh_schedules_${storyId}`, JSON.stringify(next));
    setNewScheduleOpen(false);
    setMsg("Schedule saved locally (publish runner not configured)");
  }

  if (guest) {
    return (
      <div className="container page">
        <div className="guest-lock">
          <h3>Sign in to write</h3>
          <Link className="btn btn-primary" to="/login">
            Sign in
          </Link>
        </div>
      </div>
    );
  }

  if (error) return <div className="container page error-banner">{error}</div>;
  if (!story && storyId && storyId !== "new") {
    return <div className="container page">Loading editor…</div>;
  }

  if (audioView) {
    const published = chapters.filter((c) =>
      String(c.status_text || "").toLowerCase().includes("publish")
    );
    return (
      <div className="audio-entry-page">
        <h1>No published chapters yet</h1>
        <p className="meta">
          Audiobooks are only generated for published chapters. Publish a chapter first to create its
          audiobook.
        </p>
        {published.length > 0 ? (
          <ul>
            {published.map((c) => (
              <li key={c.id}>{c.title}</li>
            ))}
          </ul>
        ) : null}
        <button type="button" className="btn btn-primary" onClick={() => setAudioView(false)}>
          Back to story editor
        </button>
      </div>
    );
  }

  const cover = resolveAssetUrl(story?.cover_path || "");
  const chapterStatus = (c) => {
    const st = String(c.status_text || "Draft").toLowerCase();
    if (st.includes("publish")) return { label: "Submitted", cls: "ok" };
    return { label: "Not Submitted", cls: "warn" };
  };

  return (
    <div className="editor-inkitt">
      <div className="editor-grid">
        {/* Left */}
        <aside className="editor-left">
          <div className="editor-cover-box">
            {cover ? <img src={cover} alt="" /> : <div className="editor-cover-empty" />}
            <button type="button" className="cover-edit-btn" disabled>
              Edit Story Cover
            </button>
          </div>
          <div className="editor-left-links">
            <button type="button" className="linkish">
              Settings
            </button>
            <Link className="linkish" to={`/stories/${storyId}`}>
              Preview
            </Link>
          </div>
          <button type="button" className="btn editor-save" onClick={saveChapter} disabled={saving}>
            💾 Save
          </button>
          {lastSaved ? <p className="meta last-saved">Last saved: {lastSaved}</p> : null}
          <button type="button" className="btn editor-audio" onClick={() => setAudioView(true)}>
            Create Audiobook
          </button>
          <div className="submit-wrap">
            <button
              type="button"
              className="btn btn-primary submit-main"
              onClick={() => submitChapter("one")}
            >
              Submit Chapter
            </button>
            <button
              type="button"
              className="btn btn-primary submit-caret"
              onClick={() => setSubmitOpen((v) => !v)}
              aria-label="More submit options"
            >
              ▾
            </button>
            {submitOpen && (
              <div className="submit-menu">
                <button type="button" onClick={() => submitChapter("all")}>
                  Submit All Chapters
                </button>
                <button type="button" onClick={() => submitChapter("withdraw")}>
                  Withdraw All Chapters
                </button>
              </div>
            )}
          </div>
          <button type="button" className="linkish schedule-link" onClick={() => setScheduleOpen(true)}>
            Schedule Manager
          </button>
          {msg ? <p className="meta editor-msg">{msg}</p> : null}
        </aside>

        {/* Center */}
        <main className="editor-center">
          <div className="story-title-row">
            <input
              className="story-title-input"
              value={storyTitle}
              onChange={(e) => setStoryTitle(e.target.value)}
              onBlur={saveStoryTitle}
            />
            <button type="button" className="edit-title-chip" onClick={saveStoryTitle}>
              Edit Title
            </button>
          </div>
          <div className="chapter-title-row">
            <h1 className="chapter-display-title">{title || "Chapter"}</h1>
            <button type="button" className="linkish" onClick={() => setNotesOpen(true)}>
              📝 Chapter Notes
            </button>
          </div>
          <div className="editor-toolbar">
            <button type="button" title="Bold" onClick={() => setContent((c) => c + "**")}>
              B
            </button>
            <button type="button" title="Italic" onClick={() => setContent((c) => c + "*")}>
              <em>I</em>
            </button>
            <button type="button" title="List" onClick={() => setContent((c) => c + "\n- ")}>
              ≡
            </button>
          </div>
          <textarea
            className="editor-textarea"
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Start writing here…"
          />
        </main>

        {/* Right chapters */}
        <aside className="editor-right">
          <h3 className="chapters-heading">CHAPTERS</h3>
          <ul className="editor-chapter-list">
            {chapters.map((c) => {
              const st = chapterStatus(c);
              const selected = String(c.id) === String(active?.id);
              return (
                <li key={c.id} className={selected ? "selected" : ""}>
                  <button type="button" className="ch-select" onClick={() => selectChapter(c)}>
                    <strong>{c.title || "Chapter"}</strong>
                    <span className="meta">
                      Chapter {c.chapter_number != null ? c.chapter_number : ""}
                    </span>
                    <span className={`ch-status ${st.cls}`}>{st.label}</span>
                  </button>
                  <div className="ch-actions">
                    <button type="button" onClick={() => renameChapter(c)}>
                      Rename
                    </button>
                    <button type="button" className="danger" onClick={() => removeChapter(c)}>
                      Delete
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
          <div className="create-chapter-box">
            <label>Create New Chapter:</label>
            <input
              value={newChapterName}
              onChange={(e) => setNewChapterName(e.target.value)}
              placeholder="Enter Chapter Name"
            />
            <button type="button" className="btn create-ch-btn" onClick={addChapter}>
              + Create Chapter
            </button>
          </div>
          <button type="button" className="btn btn-primary upload-ms" disabled title="Paste text for now">
            ↑ Upload Manuscript
          </button>
          <p className="meta upload-hint">Microsoft Word files (.doc / .docx) — coming soon; paste text in the editor.</p>
        </aside>
      </div>

      {/* Chapter notes modal */}
      {notesOpen && (
        <div className="modal-backdrop" onClick={() => setNotesOpen(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Chapter Notes</h2>
              <button type="button" className="auth-close" onClick={() => setNotesOpen(false)}>
                ×
              </button>
            </div>
            <textarea
              className="notes-area"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={6}
            />
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setNotesOpen(false)}>
                Close
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  if (active?.id) localStorage.setItem(`nh_notes_${active.id}`, notes);
                  setNotesOpen(false);
                  setMsg("Notes saved");
                }}
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Schedule manager */}
      {scheduleOpen && (
        <div className="modal-backdrop" onClick={() => setScheduleOpen(false)}>
          <div className="modal-card modal-wide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Schedule Manager</h2>
              <button type="button" className="auth-close" onClick={() => setScheduleOpen(false)}>
                ×
              </button>
            </div>
            {schedules.length === 0 ? (
              <p className="meta center-pad">No schedules for this story yet.</p>
            ) : (
              <ul className="schedule-list">
                {schedules.map((s) => (
                  <li key={s.id}>
                    <strong>{s.name || "Untitled schedule"}</strong>
                    <span className="meta">
                      {s.interval} · {s.time} · chapters {s.chapters}
                    </span>
                  </li>
                ))}
              </ul>
            )}
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setScheduleOpen(false)}>
                Close
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  setScheduleOpen(false);
                  setNewScheduleOpen(true);
                }}
              >
                Create New Schedule
              </button>
            </div>
          </div>
        </div>
      )}

      {newScheduleOpen && (
        <div className="modal-backdrop" onClick={() => setNewScheduleOpen(false)}>
          <div className="modal-card modal-wide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>New Schedule</h2>
              <button type="button" className="auth-close" onClick={() => setNewScheduleOpen(false)}>
                ×
              </button>
            </div>
            <label className="form-label">
              Schedule name
              <input
                value={scheduleForm.name}
                onChange={(e) => setScheduleForm({ ...scheduleForm, name: e.target.value })}
              />
            </label>
            <label className="form-label">
              Interval
              <select
                value={scheduleForm.interval}
                onChange={(e) => setScheduleForm({ ...scheduleForm, interval: e.target.value })}
              >
                <option>Weekly</option>
                <option>Daily</option>
                <option>Monthly</option>
              </select>
            </label>
            <div className="form-label">Days of week</div>
            <div className="days-grid">
              {["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"].map(
                (d) => (
                  <label key={d} className="day-check">
                    <input
                      type="checkbox"
                      checked={scheduleForm.days.includes(d)}
                      onChange={(e) => {
                        const days = e.target.checked
                          ? [...scheduleForm.days, d]
                          : scheduleForm.days.filter((x) => x !== d);
                        setScheduleForm({ ...scheduleForm, days });
                      }}
                    />
                    {d}
                  </label>
                )
              )}
            </div>
            <label className="form-label">
              Time
              <input
                type="time"
                value={scheduleForm.time}
                onChange={(e) => setScheduleForm({ ...scheduleForm, time: e.target.value })}
              />
            </label>
            <label className="form-label">
              Start date
              <input
                type="date"
                value={scheduleForm.start}
                onChange={(e) => setScheduleForm({ ...scheduleForm, start: e.target.value })}
              />
            </label>
            <label className="form-label">
              Chapters to publish
              <input
                value={scheduleForm.chapters}
                onChange={(e) => setScheduleForm({ ...scheduleForm, chapters: e.target.value })}
              />
            </label>
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setNewScheduleOpen(false)}>
                Cancel
              </button>
              <button type="button" className="btn btn-primary" onClick={saveSchedule}>
                Create
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
