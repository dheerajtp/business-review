
export default function StatsStrip({ stats }) {
  const total = stats.reduce((n, s) => n + s.total, 0);
  const avg = total ? stats.reduce((n, s) => n + (s.avg_rating ?? 0) * s.total, 0) / total : null;
  const attention = stats.reduce((n, s) => n + s.needs_attention, 0);
  const google = stats.reduce((n, s) => n + s.google_clicks, 0);
  const cells = [
    [String(total), 'Responses'],
    [avg === null ? '—' : avg.toFixed(1), 'Average rating'],
    [String(attention), 'Below 4 stars'],
    [String(google), 'Opened Google'],
  ];
  return (
    <div className="stats" aria-label="Summary">
      {cells.map(([n, l]) => <div key={l} className="card stat"><div className="n">{n}</div><div className="l">{l}</div></div>)}
    </div>
  );
}
