export default function StatTile({ label, value, note, change }) {
  return (
    <div className="card stat-tile">
      <p className="stat-label">{label}</p>
      <p className="stat-value">{value}</p>
      {note && <p className="small muted">{note}</p>}
      {change && (
        <p className={`stat-delta ${change.tone}`}>
          {change.arrow && <span aria-hidden="true">{change.arrow} </span>}
          {change.text}
        </p>
      )}
    </div>
  );
}
