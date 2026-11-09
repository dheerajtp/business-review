/**
 * Comparison card — two metrics stacked, each with a label, value, delta caption,
 * and a 6px rounded bar on a shared #EFEEEE track.
 *
 * Props:
 *   title    string   — card heading
 *   rows     Array<{
 *     label    string  — metric name
 *     value    string  — formatted value to display large
 *     caption  string  — small text under the value (e.g. "12 of 40 responses")
 *     change   object  — delta from lib/chart.js { text, tone, arrow }
 *     fillPct  number  — 0–100, width of the coloured bar
 *     color    string  — CSS colour for the bar fill
 *   }>
 */
export default function CompareStatCard({ title, rows }) {
  return (
    <div className="card compare-card" role="region" aria-label={title}>
      <p className="stat-label" style={{ marginBottom: 'var(--s3)', fontSize: '1rem', fontWeight: 500, color: 'var(--ink)' }}>
        {title}
      </p>

      {rows.map((row, i) => (
        <div key={row.label}>
          {i > 0 && <div className="compare-divider" />}

          <div className="compare-row">
            <div className="compare-row-top">
              <span className="compare-label">{row.label}</span>
              <span className="compare-value">{row.value}</span>
            </div>

            {row.caption && (
              <p className="compare-caption">{row.caption}</p>
            )}

            {/* Coloured progress bar on a shared track */}
            <div
              className="compare-track"
              role="meter"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(row.fillPct ?? 0)}
              aria-label={row.label}
            >
              <div
                className="compare-fill"
                style={{
                  width: `${Math.min(100, Math.max(0, row.fillPct ?? 0))}%`,
                  background: row.color,
                }}
              />
            </div>

            {row.change && (
              <p className="compare-caption" style={{ marginTop: 'var(--s1)' }}>
                <span
                  className={`delta-chip ${row.change.tone}`}
                  style={{ fontSize: '0.7rem' }}
                  aria-label={row.change.text}
                >
                  {row.change.arrow && <span aria-hidden="true">{row.change.arrow}</span>}
                  {row.change.text}
                </span>
              </p>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
