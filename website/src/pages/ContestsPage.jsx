import { Link } from "react-router-dom";

const CONTESTS = [
  {
    title: "Dark Romance Challenge",
    theme: "Forbidden love, tension, and second chances.",
    deadline: "Open entry",
    tone: "dark",
  },
  {
    title: "Myth Weaver",
    theme: "Mythology-inspired romance or drama.",
    deadline: "Open entry",
    tone: "myth",
  },
  {
    title: "First Chapter Sprint",
    theme: "Hook readers in chapter one — under 3,000 words.",
    deadline: "Rolling",
    tone: "sprint",
  },
];

export default function ContestsPage() {
  return (
    <div className="full-bleed">
      <div className="full-bleed-inner page">
        <header className="page-header">
          <h1>Writing Contests</h1>
          <p className="meta">
            Showcase your best work. Entries use the same story catalog and MySQL backend as the app.
          </p>
        </header>
        <div className="contest-list">
          {CONTESTS.map((c) => (
            <article key={c.title} className="contest-card">
              <h2>{c.title}</h2>
              <p>{c.theme}</p>
              <p className="meta">Deadline: {c.deadline}</p>
              <Link className="btn btn-primary" to="/write">
                Enter via Write
              </Link>
            </article>
          ))}
        </div>
        <p className="meta" style={{ marginTop: 24 }}>
          Contest rules and winners can later be managed from the admin panel against the same
          database.
        </p>
      </div>
    </div>
  );
}
