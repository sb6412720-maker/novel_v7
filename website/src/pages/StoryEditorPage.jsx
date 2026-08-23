import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import {
  createChapter,
  createStory,
  deleteChapter,
  getWriteStory,
  resolveAssetUrl,
  updateChapter,
  updateStory,
  uploadWriteImage,
} from "../api";
import { isGuestUser } from "../utils/guest";

const MIN_PUBLISH_CHARS = 50;
const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export default function StoryEditorPage({ user }) {
  const { storyId } = useParams();
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const guest = isGuestUser(user);
  const coverInputRef = useRef(null);

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
  const [titleModal, setTitleModal] = useState(false);
  const [titleDraft, setTitleDraft] = useState("");
  const [renameId, setRenameId] = useState(null);
  const [renameVal, setRenameVal] = useState("");
  const [scheduleOpen, setScheduleOpen] = useState(false);
  const [newScheduleOpen, setNewScheduleOpen] = useState(false);
  const [editScheduleId, setEditScheduleId] = useState(null);
  const [audioView, setAudioView] = useState(
    search.get("entry") === "audiobook" || window.location.pathname.includes("/audiobook")
  );
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [settingsTab, setSettingsTab] = useState("details");
  const [settings, setSettings] = useState({
    work_type: "original",
    work_status: "",
    series: "standalone",
    summary: "",
    story_notes: "",
    genre: "Romance",
    genre2: "",
    tags: "",
    age_rating: "13+",
    content_warnings: "",
    ai_assisted: "original",
    availability: "web_app",
    language: "English",
    inline_comments: true,
    expand_languages: true,
  });
  const [scheduleForm, setScheduleForm] = useState({
    name: "",
    interval: "Weekly",
    days: [],
    timezone: "Asia/Colombo",
    time: "05:00",
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

  function persistSchedules(list) {
    setSchedules(list);
    localStorage.setItem(`nh_schedules_${storyId}`, JSON.stringify(list));
  }

  async function load(id) {
    const res = await getWriteStory(id);
    const s = res?.story || res?.item || res;
    let ch = res?.chapters || res?.items || [];
    if (!Array.isArray(ch)) ch = [];
    // Normalize chapter fields from backend
    ch = ch.map((c) => ({
      ...c,
      id: c.id,
      title: c.title || `Chapter ${c.chapter_number || ""}`,
      content: c.content || "",
      notes: c.notes || "",
      submission_status: c.submission_status || "draft",
      chapter_number: c.chapter_number,
    }));
    setStory(s);
    setStoryTitle(s?.title || "Untitled Story");
    setSettings((prev) => ({
      ...prev,
      summary: s?.description || "",
      genre: s?.genre || s?.primary_genre || prev.genre || "Romance",
      content_warnings: s?.content_warnings || "",
      work_status: s?.status_text || prev.work_status || "",
      story_notes: localStorage.getItem(`nh_story_notes_${id}`) || prev.story_notes || "",
      age_rating: localStorage.getItem(`nh_age_${id}`) || prev.age_rating,
      work_type: localStorage.getItem(`nh_work_type_${id}`) || prev.work_type,
      tags: localStorage.getItem(`nh_tags_${id}`) || prev.tags,
    }));

    if (!ch.length) {
      try {
        const created = await createChapter(id, {
          title: "Chapter 1",
          content: "",
          chapter_number: 1,
          submission_status: "draft",
        });
        const res2 = await getWriteStory(id);
        ch = res2?.chapters || res2?.items || [];
        if (!ch.length && (created?.id || created?.chapter_id)) {
          ch = [{
            id: created.id || created.chapter_id,
            title: "Chapter 1",
            content: "",
            notes: "",
            submission_status: "draft",
            chapter_number: 1,
          }];
        }
      } catch (ce) {
        setMsg(String(ce.message || ce));
      }
    }

    ch = (Array.isArray(ch) ? ch : []).map((c) => ({
      ...c,
      title: c.title || `Chapter ${c.chapter_number || ""}`,
      content: c.content || "",
      notes: c.notes || "",
      submission_status: c.submission_status || "draft",
    }));
    setChapters(ch);
    const prefer = activeId && ch.find((c) => String(c.id) === String(activeId));
    const pick = prefer || ch[0];
    if (pick) {
      setActiveId(pick.id);
      setTitle(pick.title || "Chapter 1");
      setContent(pick.content || "");
      setNotes(pick.notes || localStorage.getItem(`nh_notes_${pick.id}`) || "");
    } else {
      setActiveId(null);
      setTitle("");
      setContent("");
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
            author: user?.display_name || user?.username || user?.email || "Author",
            description: "",
            status_text: "Draft",
            genre: "Romance",
          });
          const id = res?.id || res?.story_id || res?.item?.id;
          if (id && !cancelled) navigate(`/write/${id}`, { replace: true });
          return;
        }
        await load(storyId);
        try {
          setSchedules(JSON.parse(localStorage.getItem(`nh_schedules_${storyId}`) || "[]"));
        } catch {
          /* ignore */
        }
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
    setRenameId(null);
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
      await updateChapter(active.id, { title, content, notes });
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

  async function saveStoryTitleModal() {
    if (!storyId) return;
    try {
      await updateStory(storyId, { title: (titleDraft || "Untitled Story").trim() });
      setStoryTitle(titleDraft.trim() || "Untitled Story");
      setTitleModal(false);
      setMsg("Title updated");
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function onCoverFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setMsg("Uploading cover…");
    try {
      const up = await uploadWriteImage(file);
      let path = up?.path || up?.url || up?.cover_path || up?.filename;
      if (!path) throw new Error("No path returned from upload");
      if (!String(path).startsWith("/") && !String(path).startsWith("http")) {
        path = `/uploads/${path}`;
      }
      await updateStory(storyId, { cover_path: path });
      setStory((s) => (s ? { ...s, cover_path: path } : s));
      setMsg("Cover updated");
      await load(storyId);
    } catch (err) {
      setMsg(String(err.message || err));
    } finally {
      if (coverInputRef.current) coverInputRef.current.value = "";
    }
  }

  async function addChapter() {
    const name = (newChapterName || `Chapter ${chapters.length + 1}`).trim();
    try {
      const res = await createChapter(storyId, {
        title: name,
        content: "",
        chapter_number: chapters.length + 1,
        submission_status: "draft",
      });
      setNewChapterName("");
      const id = res?.id || res?.chapter_id || res?.item?.id;
      // Optimistic list update so UI shows immediately
      if (id) {
        setChapters((prev) => [
          ...prev,
          {
            id,
            title: name,
            content: "",
            notes: "",
            submission_status: "draft",
            chapter_number: chapters.length + 1,
          },
        ]);
        setActiveId(id);
        setTitle(name);
        setContent("");
        setNotes("");
      }
      await load(storyId);
      if (id) setActiveId(id);
      setMsg("Chapter created");
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  async function applyRename(c) {
    const next = (renameVal || "").trim();
    if (!next) {
      setRenameId(null);
      return;
    }
    try {
      await updateChapter(c.id, { title: next });
      setRenameId(null);
      if (String(c.id) === String(active?.id)) setTitle(next);
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

    async function removeChapter(c) {
    if (!window.confirm(`Delete "${c.title || "chapter"}"?`)) return;
    try {
      await deleteChapter(c.id);
      if (String(activeId) === String(c.id)) {
        setActiveId(null);
        setTitle("");
        setContent("");
      }
      await load(storyId);
      setMsg("Chapter deleted");
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  function canPublish(text) {
    return String(text || "").replace(/\s+/g, " ").trim().length >= MIN_PUBLISH_CHARS;
  }

  async function submitChapter(mode) {
    setSubmitOpen(false);
    try {
      if (mode === "one") {
        if (!active?.id) {
          setMsg("Select a chapter");
          return;
        }
        if (!canPublish(content)) {
          await updateChapter(active.id, { title, content, submission_status: "draft" });
          await updateStory(storyId, { status_text: "Draft" });
          setMsg(`Need at least ${MIN_PUBLISH_CHARS} characters — kept as draft`);
        } else {
          await updateChapter(active.id, {
            title,
            content,
            submission_status: "published",
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
              submission_status: "published",
            });
            any = true;
          } else {
            await updateChapter(c.id, {
              title: c.id === active?.id ? title : c.title,
              content: body,
              submission_status: "draft",
            });
          }
        }
        await updateStory(storyId, { status_text: any ? "Published" : "Draft" });
        setMsg(any ? "Submitted eligible chapters" : "No chapter met 50-char rule");
      } else if (mode === "withdraw") {
        for (const c of chapters) {
          await updateChapter(c.id, { submission_status: "draft" });
        }
        await updateStory(storyId, { status_text: "Draft" });
        setMsg("All chapters withdrawn to draft");
      }
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
  }

  function openNewSchedule() {
    setEditScheduleId(null);
    setScheduleForm({
      name: "",
      interval: "Weekly",
      days: [],
      timezone: "Asia/Colombo",
      time: new Date().toTimeString().slice(0, 5),
      start: new Date().toISOString().slice(0, 10),
      chapters: "1",
    });
    setScheduleOpen(false);
    setNewScheduleOpen(true);
  }

  function openEditSchedule(s) {
    setEditScheduleId(s.id);
    setScheduleForm({
      name: s.name || "",
      interval: s.interval || "Weekly",
      days: s.days || [],
      timezone: s.timezone || "Asia/Colombo",
      time: s.time || "05:00",
      start: s.start || new Date().toISOString().slice(0, 10),
      chapters: s.chapters || "1",
    });
    setScheduleOpen(false);
    setNewScheduleOpen(true);
  }

  function saveSchedule() {
    if (!(scheduleForm.name || "").trim()) {
      setMsg("Schedule name required");
      return;
    }
    const item = {
      id: editScheduleId || Date.now(),
      ...scheduleForm,
      name: scheduleForm.name.trim(),
    };
    const next = editScheduleId
      ? schedules.map((s) => (s.id === editScheduleId ? item : s))
      : [...schedules, item];
    persistSchedules(next);
    setNewScheduleOpen(false);
    setScheduleOpen(true);
    setMsg("Schedule saved");
  }

  function formatScheduleLine(s) {
    const days =
      s.days?.length > 0
        ? `on ${s.days.map((d) => d + "s").join(", ")}`
        : "";
    return `${s.chapters || 1} chapters ${(s.interval || "weekly").toLowerCase()} ${days} @ ${s.time || ""} ${s.timezone || ""} - Free for everyone`;
  }

  function isPublishedChapter(c) {
    const st = String(c.submission_status || c.status_text || "").toLowerCase();
    return st.includes("publish") || st === "submitted";
  }


  async function saveSettings() {
    if (!storyId) return;
    try {
      await updateStory(storyId, {
        description: (settings.summary || "").slice(0, 1400),
        genre: settings.genre || "Romance",
        content_warnings: settings.content_warnings || "",
        status_text: settings.work_status || undefined,
        tags: settings.tags
          ? String(settings.tags)
              .split(",")
              .map((t) => t.trim())
              .filter(Boolean)
          : [],
      });
      localStorage.setItem(`nh_story_notes_${storyId}`, settings.story_notes || "");
      localStorage.setItem(`nh_age_${storyId}`, settings.age_rating || "13+");
      localStorage.setItem(`nh_work_type_${storyId}`, settings.work_type || "original");
      localStorage.setItem(`nh_tags_${storyId}`, settings.tags || "");
      localStorage.setItem(
        `nh_settings_${storyId}`,
        JSON.stringify({
          series: settings.series,
          ai_assisted: settings.ai_assisted,
          availability: settings.availability,
          language: settings.language,
          inline_comments: settings.inline_comments,
          expand_languages: settings.expand_languages,
        })
      );
      setMsg("Story settings saved");
      setSettingsOpen(false);
      await load(storyId);
    } catch (e) {
      setMsg(String(e.message || e));
    }
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
    const published = chapters.filter(isPublishedChapter);
    return (
      <div className="audio-entry-page">
        <h1>No published chapters yet</h1>
        <p className="meta">
          Audiobooks are only generated for published chapters. Publish a chapter first to create its
          audiobook.
        </p>
        {published.length > 0 ? (
          <>
            <p className="meta">Published chapters ready:</p>
            <ul style={{ textAlign: "left", maxWidth: 360, margin: "12px auto" }}>
              {published.map((c) => (
                <li key={c.id}>{c.title}</li>
              ))}
            </ul>
          </>
        ) : null}
        <button type="button" className="btn btn-primary" onClick={() => setAudioView(false)}>
          Back to story editor
        </button>
      </div>
    );
  }

  const cover = resolveAssetUrl(story?.cover_path || "");
  const chapterStatus = (c) => {
    if (isPublishedChapter(c)) return { label: "Submitted", cls: "ok" };
    return { label: "Not Submitted", cls: "warn" };
  };

  return (
    <div className="editor-inkitt">
      <div className="editor-grid">
        <aside className="editor-left">
          <div className="editor-cover-box">
            {cover ? (
              <img src={cover} alt="Cover" />
            ) : (
              <div className="editor-cover-empty" aria-hidden="true" />
            )}
            <button
              type="button"
              className="cover-edit-btn"
              onClick={() => coverInputRef.current?.click()}
            >
              Edit Story Cover
            </button>
            <input
              ref={coverInputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp,image/jpg"
              style={{ display: "none" }}
              onChange={onCoverFile}
            />
          </div>
          <div className="editor-left-links">
            <button type="button" className="linkish" onClick={() => setSettingsOpen(true)}>
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
              {schedules.length ? "Add to schedules" : "Submit Chapter"}
            </button>
            <button
              type="button"
              className="btn btn-primary submit-caret"
              onClick={() => setSubmitOpen((v) => !v)}
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

        <main className="editor-center">
          <div className="story-title-row">
            <span className="story-title-display">{(storyTitle || "UNTITLED STORY").toUpperCase()}</span>
            <button
              type="button"
              className="edit-title-chip"
              onClick={() => {
                setTitleDraft(storyTitle || "Untitled Story");
                setTitleModal(true);
              }}
            >
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
            <button type="button" onClick={() => setContent((c) => `${c}**`)}>
              B
            </button>
            <button type="button" onClick={() => setContent((c) => `${c}*`)}>
              <em>I</em>
            </button>
            <button type="button" onClick={() => setContent((c) => `${c}\n- `)}>
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

        <aside className="editor-right">
          <h3 className="chapters-heading">CHAPTERS</h3>
          <ul className="editor-chapter-list">
            {chapters.map((c) => {
              const st = chapterStatus(c);
              const selected = String(c.id) === String(active?.id);
              const renaming = String(renameId) === String(c.id);
              return (
                <li key={c.id} className={selected ? "selected" : ""}>
                  {renaming ? (
                    <div className="ch-rename-box">
                      <input
                        value={renameVal}
                        onChange={(e) => setRenameVal(e.target.value)}
                        autoFocus
                        onKeyDown={(e) => {
                          if (e.key === "Enter") applyRename(c);
                          if (e.key === "Escape") setRenameId(null);
                        }}
                      />
                      <button type="button" className="btn btn-primary btn-sm" onClick={() => applyRename(c)}>
                        + Rename
                      </button>
                    </div>
                  ) : (
                    <>
                      <button type="button" className="ch-select" onClick={() => selectChapter(c)}>
                        <strong>{c.title || "Chapter"}</strong>
                        <span className="meta">
                          Chapter {c.chapter_number != null ? c.chapter_number : ""}
                        </span>
                        <span className={`ch-status ${st.cls}`}>{st.label}</span>
                      </button>
                      <div className="ch-actions">
                        <button
                          type="button"
                          onClick={() => {
                            setRenameId(c.id);
                            setRenameVal(c.title || "");
                          }}
                        >
                          Rename
                        </button>
                        <button type="button" className="danger" onClick={() => removeChapter(c)}>
                          Delete
                        </button>
                      </div>
                    </>
                  )}
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
          <button type="button" className="btn btn-primary upload-ms" disabled>
            ↑ Upload Manuscript
          </button>
          <p className="meta upload-hint">
            Microsoft Word files (.doc / .docx) — paste text in the editor for now.
          </p>
        </aside>
      </div>

      {/* Change Story Title */}
      {titleModal && (
        <div className="modal-backdrop" onClick={() => setTitleModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Change Story Title</h2>
              <button type="button" className="auth-close" onClick={() => setTitleModal(false)}>
                ×
              </button>
            </div>
            <p className="meta">Enter a new title for your story:</p>
            <input
              className="title-modal-input"
              value={titleDraft}
              onChange={(e) => setTitleDraft(e.target.value)}
              autoFocus
            />
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setTitleModal(false)}>
                Close
              </button>
              <button type="button" className="btn btn-primary" onClick={saveStoryTitleModal}>
                Save
              </button>
            </div>
          </div>
        </div>
      )}

      {notesOpen && (
        <div className="modal-backdrop" onClick={() => setNotesOpen(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Chapter Notes</h2>
              <button type="button" className="auth-close" onClick={() => setNotesOpen(false)}>
                ×
              </button>
            </div>
            <div className="editor-toolbar" style={{ borderRadius: 6, marginBottom: 0 }}>
              <button type="button">B</button>
              <button type="button">
                <em>I</em>
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
                onClick={async () => {
                  if (active?.id) {
                    localStorage.setItem(`nh_notes_${active.id}`, notes);
                    try {
                      await updateChapter(active.id, { notes });
                    } catch (_) {}
                  }
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
                  <li key={s.id} className="schedule-row">
                    <div>
                      <strong>{s.name}</strong>
                      <p className="meta">{formatScheduleLine(s)}</p>
                    </div>
                    <button type="button" className="btn schedule-edit" onClick={() => openEditSchedule(s)}>
                      Edit
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setScheduleOpen(false)}>
                Close
              </button>
              <button type="button" className="btn btn-primary" onClick={openNewSchedule}>
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
              <h2>{editScheduleId ? "Edit Schedule" : "New Schedule"}</h2>
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
              {DAYS.map((d) => (
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
              ))}
            </div>
            <label className="form-label">
              Timezone
              <select
                value={scheduleForm.timezone}
                onChange={(e) => setScheduleForm({ ...scheduleForm, timezone: e.target.value })}
              >
                <option>Asia/Colombo</option>
                <option>UTC</option>
                <option>America/New_York</option>
                <option>Europe/London</option>
              </select>
            </label>
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
                {editScheduleId ? "Save" : "Create"}
              </button>
            </div>
          </div>
        </div>
      )}

      {settingsOpen && (
        <div className="settings-drawer-backdrop" onClick={() => setSettingsOpen(false)}>
          <div className="settings-drawer" onClick={(e) => e.stopPropagation()}>
            <div className="settings-drawer-head">
              <h2>Story Settings</h2>
              <button type="button" className="auth-close" onClick={() => setSettingsOpen(false)}>×</button>
            </div>
            <div className="settings-drawer-body">
              <nav className="settings-nav">
                {[
                  ["details", "Story Details"],
                  ["genres", "Genres and Tags"],
                  ["warnings", "Content Warnings"],
                  ["publish", "Publishing and Contests"],
                ].map(([id, label]) => (
                  <button key={id} type="button" className={settingsTab === id ? "active" : ""} onClick={() => setSettingsTab(id)}>
                    {label}
                  </button>
                ))}
              </nav>
              <div className="settings-panel">
                {settingsTab === "details" && (
                  <section>
                    <h3>Story Details</h3>
                    <div className="settings-toggle-row">
                      <button type="button" className={settings.work_type === "original" ? "on" : ""} onClick={() => setSettings({ ...settings, work_type: "original" })}>Original</button>
                      <button type="button" className={settings.work_type === "fanfiction" ? "on" : ""} onClick={() => setSettings({ ...settings, work_type: "fanfiction" })}>Fanfiction</button>
                    </div>
                    <label className="form-label">Work Status
                      <select value={settings.work_status} onChange={(e) => setSettings({ ...settings, work_status: e.target.value })}>
                        <option value="">Nothing selected</option>
                        <option value="Ongoing">Ongoing</option>
                        <option value="Complete">Complete</option>
                        <option value="Hiatus">Hiatus</option>
                        <option value="Draft">Draft</option>
                      </select>
                    </label>
                    <div className="form-label">Series Placement</div>
                    <label className="radio-row"><input type="radio" checked={settings.series === "standalone"} onChange={() => setSettings({ ...settings, series: "standalone" })} /> Standalone story</label>
                    <label className="radio-row"><input type="radio" checked={settings.series === "series"} onChange={() => setSettings({ ...settings, series: "series" })} /> Part of a series</label>
                    <label className="form-label">Summary (max. 1400 characters)
                      <textarea value={settings.summary} maxLength={1400} rows={4} placeholder="Hook readers with a teaser that captures your story's vibe—short, punchy, and impossible to ignore." onChange={(e) => setSettings({ ...settings, summary: e.target.value })} />
                    </label>
                    <label className="form-label">Story Notes
                      <textarea value={settings.story_notes} rows={3} placeholder="Share a note to set the tone..." onChange={(e) => setSettings({ ...settings, story_notes: e.target.value })} />
                    </label>
                  </section>
                )}
                {settingsTab === "genres" && (
                  <section>
                    <h3>Genres and Tags</h3>
                    <label className="form-label">Genre
                      <select value={settings.genre} onChange={(e) => setSettings({ ...settings, genre: e.target.value })}>
                        <option value="">Nothing selected</option>
                        {["Romance","Fantasy","Thriller","Young Adult","Sci-Fi","Drama","Adventure","Mystery","Horror","Werewolves","Contemporary Romance","Other"].map((g) => (
                          <option key={g} value={g}>{g}</option>
                        ))}
                      </select>
                    </label>
                    <p className="meta">0/4 sub-genres selected — choose up to 4 across all genres.</p>
                    <label className="form-label">Tags (comma-separated)
                      <input value={settings.tags} placeholder="Alpha, Boss, Second Chance" onChange={(e) => setSettings({ ...settings, tags: e.target.value })} />
                    </label>
                    <div className="form-label">Age Rating</div>
                    {[
                      ["13+", "Kids (13+)", "May contain some violence, minor coarse language, and minor suggestive adult themes."],
                      ["16+", "Teenager (16+)", "May contain non-explicit suggestive adult themes, references to some violence, or coarse language."],
                      ["18+", "Adults (18+)", "May contain explicit language and adult themes."],
                    ].map(([val, label, hint]) => (
                      <label key={val} className="radio-card">
                        <input type="radio" checked={settings.age_rating === val} onChange={() => setSettings({ ...settings, age_rating: val })} />
                        <span><strong>{label}</strong><span className="meta">{hint}</span></span>
                      </label>
                    ))}
                  </section>
                )}
                {settingsTab === "warnings" && (
                  <section>
                    <h3>Content Warnings</h3>
                    <label className="form-label">Trigger Warnings
                      <select value={settings.content_warnings} onChange={(e) => setSettings({ ...settings, content_warnings: e.target.value })}>
                        <option value="">No warnings selected</option>
                        <option value="Violence">Violence</option>
                        <option value="Abuse">Abuse</option>
                        <option value="Sexual content">Sexual content</option>
                        <option value="Death">Death</option>
                        <option value="Other">Other</option>
                      </select>
                    </label>
                    <div className="form-label">AI Assisted</div>
                    <label className="radio-row"><input type="radio" checked={settings.ai_assisted === "ai"} onChange={() => setSettings({ ...settings, ai_assisted: "ai" })} /> AI participated in the storytelling</label>
                    <label className="radio-row"><input type="radio" checked={settings.ai_assisted === "original"} onChange={() => setSettings({ ...settings, ai_assisted: "original" })} /> This is fully original content</label>
                  </section>
                )}
                {settingsTab === "publish" && (
                  <section>
                    <h3>Publishing and Contests</h3>
                    <div className="form-label">Story Availability</div>
                    <label className="radio-row"><input type="radio" checked={settings.availability === "web_app"} onChange={() => setSettings({ ...settings, availability: "web_app" })} /> Website and App</label>
                    <label className="radio-row"><input type="radio" checked={settings.availability === "app"} onChange={() => setSettings({ ...settings, availability: "app" })} /> App only</label>
                    <label className="form-label">Story Language
                      <select value={settings.language} onChange={(e) => setSettings({ ...settings, language: e.target.value })}>
                        <option>English</option><option>Spanish</option><option>French</option><option>German</option>
                      </select>
                    </label>
                    <div className="form-label">Inline Commenting</div>
                    <label className="radio-row"><input type="radio" checked={!settings.inline_comments} onChange={() => setSettings({ ...settings, inline_comments: false })} /> Turn off paragraph-level comments and reactions</label>
                    <label className="radio-row"><input type="radio" checked={!!settings.inline_comments} onChange={() => setSettings({ ...settings, inline_comments: true })} /> Turn on paragraph-level reactions and feedback</label>
                    <label className="form-label">Participate in contest
                      <select disabled><option>You must publish your story before you can participate!</option></select>
                    </label>
                    <div className="form-label">Expand my readership in other languages</div>
                    <label className="radio-row"><input type="radio" checked={!!settings.expand_languages} onChange={() => setSettings({ ...settings, expand_languages: true })} /> Yes</label>
                    <label className="radio-row"><input type="radio" checked={!settings.expand_languages} onChange={() => setSettings({ ...settings, expand_languages: false })} /> No</label>
                  </section>
                )}
              </div>
            </div>
            <div className="settings-drawer-foot">
              <button type="button" className="btn" onClick={() => setSettingsOpen(false)}>Close</button>
              <button type="button" className="btn btn-primary" onClick={saveSettings}>Save</button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
