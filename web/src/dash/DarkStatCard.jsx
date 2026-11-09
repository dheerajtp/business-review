import { Link } from 'react-router-dom';

/**
 * Dark gradient headline card — used for the primary KPI (Responses).
 * Props:
 *   label      string   — small muted label above the value
 *   value      string   — large white number
 *   change     object   — delta from lib/chart.js { text, tone, arrow }
 *   linkTo     string   — href for the "View more" link (optional)
 *   linkLabel  string   — link text (default "View more")
 *   note       string   — small muted text bottom-right (optional)
 */
export default function DarkStatCard({ label, value, change, linkTo, linkLabel = 'View more', note }) {
  return (
    <div className="dark-card" role="region" aria-label={label}>
      <p className="dark-card-label">{label}</p>
      <p className="dark-card-value">{value}</p>

      {change && (
        <span className={`delta-chip ${change.tone}`} aria-label={change.text}>
          {change.arrow && <span aria-hidden="true">{change.arrow}</span>}
          {change.text}
        </span>
      )}

      <div className="dark-card-footer">
        {linkTo ? (
          <Link to={linkTo} className="dark-card-link">{linkLabel} →</Link>
        ) : (
          <span />
        )}
        {note && <span className="dark-card-note">{note}</span>}
      </div>
    </div>
  );
}
