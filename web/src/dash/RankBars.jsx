import { useState } from 'react';
import { pct } from '../lib/chart';

const LIMIT = 8;

/** Average rating (0–5) per company or branch, lowest first. Rows are buttons when `onSelect` is given. */
export default function RankBars({ rows, onSelect, unit }) {
  const [all, setAll] = useState(false);
  const shown = all ? rows : rows.slice(0, LIMIT);

  return (
    <>
      <ul className="rank">
        {shown.map((r) => {
          const body = (
            <>
              <span className="rank-name">
                <strong>{r.name}</strong>
                <span className="small muted">
                  {r.company ? `${r.company} · ` : ''}
                  {r.total === 0 ? 'No responses yet' : `${r.total} ${r.total === 1 ? 'response' : 'responses'} · ${pct(r.low, r.total)}% below 4★`}
                </span>
              </span>
              <span className="hbar-track rank-track">
                {r.total > 0 && (
                  <>
                    <span className="hbar-fill" style={{ width: `${(r.avg / 5) * 100}%` }} />
                    <span className="hbar-tip" style={{ left: `${(r.avg / 5) * 100}%` }}>{Number(r.avg).toFixed(1)}</span>
                  </>
                )}
              </span>
            </>
          );
          return (
            <li key={r.id}>
              {onSelect
                ? <button type="button" className="rank-row" onClick={() => onSelect(r.id)} aria-label={`${r.name}: show only this ${unit}`}>{body}</button>
                : <div className="rank-row">{body}</div>}
            </li>
          );
        })}
      </ul>
      {rows.length > LIMIT && (
        <button type="button" className="btn sm ghost" style={{ marginTop: 8 }} onClick={() => setAll(!all)}>
          {all ? 'Show fewer' : `Show all ${rows.length}`}
        </button>
      )}
    </>
  );
}
