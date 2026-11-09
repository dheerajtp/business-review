import { useState } from 'react';
import ChartTooltip from './ChartTooltip';
import { fmtDay, fmtDayLong, niceTicks } from '../lib/chart';
import { useWidth } from '../lib/useWidth';

const H = 320;
const M = { l: 36, r: 8, t: 8, b: 28 };
const GAP = 2;
const GOOD = 'var(--viz-good)';
const BAD = 'var(--viz-bad)';

// Column with a 4px rounded top and a square base.
function column(x, top, w, h, round) {
  if (h <= 0) return '';
  const r = round ? Math.min(4, h, w / 2) : 0;
  return `M${x},${top + h}L${x},${top + r}${r ? `Q${x},${top} ${x + r},${top}` : ''}L${x + w - r},${top}${r ? `Q${x + w},${top} ${x + w},${top + r}` : ''}L${x + w},${top + h}Z`;
}

export default function TimeBars({ daily }) {
  const [ref, width] = useWidth();
  const [hover, setHover] = useState(null);

  const n = daily.length;
  const ticks = niceTicks(Math.max(...daily.map((d) => d.high + d.low), 0), 4);
  const top = ticks[ticks.length - 1];
  const iw = Math.max(0, width - M.l - M.r);
  const ih = H - M.t - M.b;
  const band = n ? iw / n : 0;
  const bw = Math.max(2, Math.min(24, band - 2));
  const y0 = M.t + ih;
  const seg = (v) => (v > 0 ? Math.max(2, (v / top) * ih) : 0);
  // Leave ~64px per date label so they never touch, whatever the width.
  const labelEvery = Math.max(1, Math.ceil(n / Math.max(2, Math.floor(iw / 64))));
  const total = daily.reduce((s, d) => s + d.high + d.low, 0);

  const h = hover === null ? null : daily[hover];
  const hx = hover === null ? 0 : M.l + band * (hover + 0.5);
  const hy = h ? y0 - seg(h.high) - seg(h.low) : 0;

  return (
    <div className="chart-wrap" ref={ref} style={{ height: H }} onPointerLeave={() => setHover(null)}>
      {width > 0 && (
        <svg width={width} height={H} role="img" aria-label={`Responses per day over ${n} days, ${total} in total. A table view is available.`}>
          {ticks.map((t) => (
            <g key={t}>
              <line x1={M.l} x2={width - M.r} y1={y0 - (t / top) * ih} y2={y0 - (t / top) * ih} className="viz-grid" />
              <text x={M.l - 6} y={y0 - (t / top) * ih + 4} textAnchor="end" className="viz-axis">{t}</text>
            </g>
          ))}
          {daily.map((d, i) => {
            const x = M.l + band * i + (band - bw) / 2;
            const hh = seg(d.high);
            const lh = seg(d.low);
            const dim = hover !== null && hover !== i;
            return (
              <g key={d.day} opacity={dim ? 0.55 : 1}>
                <path d={column(x, y0 - hh, bw, hh, lh === 0)} fill={GOOD} />
                <path d={column(x, y0 - hh - (hh ? GAP : 0) - lh, bw, lh, true)} fill={BAD} />
                {i % labelEvery === 0 && <text x={x + bw / 2} y={H - 8} textAnchor="middle" className="viz-axis">{fmtDay(d.day)}</text>}
              </g>
            );
          })}
          {daily.map((d, i) => (
            <rect key={d.day} x={M.l + band * i} y={M.t} width={band} height={ih} fill="transparent" onPointerMove={() => setHover(i)} onPointerEnter={() => setHover(i)} />
          ))}
        </svg>
      )}
      {h && (
        <ChartTooltip
          x={hx} y={hy} width={width} title={fmtDayLong(h.day)}
          rows={[
            { label: '4–5 stars', value: h.high, color: GOOD },
            { label: 'Below 4 stars', value: h.low, color: BAD },
          ]}
        />
      )}
    </div>
  );
}
