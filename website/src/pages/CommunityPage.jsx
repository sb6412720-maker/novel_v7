import { Link } from "react-router-dom";

const GROUPS = [
  { name: "NovelHub Community", blurb: "Welcome hub — introduce yourself and meet readers." },
  { name: "Beta-readers", blurb: "Swap constructive feedback on drafts." },
  { name: "Review Me", blurb: "Ask for reviews and discover new stories." },
  { name: "Writing & Editing", blurb: "Plots, style, writer’s block, craft." },
  { name: "Romance", blurb: "Genre-specific discussion." },
  { name: "Fantasy", blurb: "Worldbuilding and epic reads." },
];

export default function CommunityPage() {
  return (
    <div className="full-bleed">
      <div className="full-bleed-inner page">
        <header className="page-header">
          <h1>Community</h1>
          <p className="meta">Groups and discussion — structure mirrors Inkitt; activity can use wall APIs next.</p>
        </header>
        <div className="groups-grid">
          {GROUPS.map((g) => (
            <div key={g.name} className="group-card">
              <h3>{g.name}</h3>
              <p>{g.blurb}</p>
              <Link to="/discover" className="see-all">
                Browse stories →
              </Link>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
