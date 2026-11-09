const dayFmt = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short' });
const weekdayFmt = new Intl.DateTimeFormat(undefined, { weekday: 'short', day: 'numeric', month: 'short' });
const parseDay = (iso) => new Date(`${iso}T00:00:00`);
export const fmtDay = (iso) => dayFmt.format(parseDay(iso));
export const fmtDayLong = (iso) => weekdayFmt.format(parseDay(iso));

/** Round y-axis ticks (0, 5, 10 ...) whose last value is >= max. Counts are whole numbers. */
export function niceTicks(max, target = 4) {
  if (max <= 0) return [0, 1];
  const raw = max / target;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = Math.max(1, [1, 2, 5, 10].map((m) => m * mag).find((s) => s >= raw));
  const ticks = [];
  for (let v = 0; ; v += step) {
    ticks.push(v);
    if (v >= max) break;
  }
  return ticks;
}

export const pct = (n, d) => (d ? Math.round((n / d) * 100) : 0);
export const num = (n) => new Intl.NumberFormat().format(n);

/** Delta between two periods. `upIsGood` decides the tone; kind 'pct' = relative %, 'pp' = percentage points, 'abs' = plain difference. */
export function delta(cur, prev, { kind, upIsGood, days }) {
  const label = `vs previous ${days} days`;
  // Nothing to compare against: show no delta at all rather than a placeholder.
  if (cur === null || prev === null || prev === undefined) return null;
  let diff;
  let text;
  if (kind === 'pct') {
    if (prev === 0) return null;
    diff = ((cur - prev) / prev) * 100;
    text = `${Math.abs(Math.round(diff))}%`;
  } else if (kind === 'pp') {
    diff = cur - prev;
    text = `${Math.abs(Math.round(diff))} pts`;
  } else {
    diff = cur - prev;
    text = Math.abs(diff).toFixed(1);
  }
  if (Math.abs(diff) < (kind === 'abs' ? 0.05 : 0.5)) return { text: `no change ${label}`, tone: 'flat', arrow: '' };
  const up = diff > 0;
  return { text: `${text} ${label}`, tone: up === upIsGood ? 'good' : 'bad', arrow: up ? '▲' : '▼' };
}
