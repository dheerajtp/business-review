import Stars from '../ui/Stars';
import { formatDateTime } from '../lib/format';

export default function SubmissionCard({ s, branchName, companyName, isNew }) {
  const urgent = s.rating <= 2;
  return (
    <article className={`item${urgent ? ' attention' : ''}`} style={{ alignItems: 'flex-start' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="row" style={{ gap: 8 }}>
          <Stars rating={s.rating} />
          {isNew && <span className="pill new">New</span>}
          {urgent && <span className="pill bad">Urgent</span>}
          {s.rating === 3 && <span className="pill warn">Needs attention</span>}
          {s.clicked_google && <span className="pill">Opened Google</span>}
        </div>
        <div className="small muted" style={{ marginTop: 4 }}>
          {companyName && `${companyName} · `}{branchName} · {formatDateTime(s.created_at)}
        </div>
        {s.comment && <p style={{ marginTop: 8, whiteSpace: 'pre-wrap' }}>{s.comment}</p>}
        {s.contact && <p className="small" style={{ marginTop: 8 }}><strong>Contact:</strong> {s.contact}</p>}
        {s.keywords?.length > 0 && (
          <ul className="kw-list">
            {s.keywords.map((k) => <li key={k.id} className="pill">{k.label}</li>)}
          </ul>
        )}
      </div>
    </article>
  );
}
