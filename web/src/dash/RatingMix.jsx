import { num, pct } from '../lib/chart';

/** Horizontal bars, 5 stars at the top. One series, one colour; values sit at the bar tip. */
export default function RatingMix({ mix }) {
  const total = mix.reduce((s, m) => s + m.n, 0);
  const max = Math.max(...mix.map((m) => m.n), 1);
  return (
    <ul className="hbars" aria-label="Responses by star rating">
      {[...mix].reverse().map((m) => (
        <li key={m.rating} className="hbar" title={`${m.rating} stars: ${m.n} (${pct(m.n, total)}%)`}>
          <span className="hbar-label">{m.rating} <span aria-hidden="true">★</span><span className="sr-only"> stars</span></span>
          <span className="hbar-track">
            {m.n > 0 && <span className="hbar-fill" style={{ width: `${(m.n / max) * 100}%` }} />}
            <span className="hbar-tip" style={{ left: `${(m.n / max) * 100}%` }}>{num(m.n)} <span className="muted">· {pct(m.n, total)}%</span></span>
          </span>
        </li>
      ))}
    </ul>
  );
}
