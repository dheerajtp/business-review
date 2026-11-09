import { num, pct } from '../lib/chart';

/** Meter: the track is a lighter step of the fill's own hue. */
export default function GoogleMeter({ happy, google }) {
  const p = pct(google, happy);
  return (
    <div>
      <p className="stat-value">{happy ? `${p}%` : '—'}</p>
      <div className="meter" role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={p} aria-label="Happy customers who opened the Google review page">
        <span style={{ width: `${p}%` }} />
      </div>
      <p className="small muted" style={{ marginTop: 8 }}>
        {num(google)} of {num(happy)} customers who gave 4–5 stars opened the Google review page.
      </p>
    </div>
  );
}
