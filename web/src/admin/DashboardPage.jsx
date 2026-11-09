import { useState } from 'react';
import ChartCard from '../dash/ChartCard';
import CompareStatCard from '../dash/CompareStatCard';
import DarkStatCard from '../dash/DarkStatCard';
import DataTable from '../dash/DataTable';
import GoogleMeter from '../dash/GoogleMeter';
import RankBars from '../dash/RankBars';
import RatingMix from '../dash/RatingMix';
import TimeBars from '../dash/TimeBars';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import PageHead from '../ui/PageHead';
import { delta, fmtDayLong, num, pct } from '../lib/chart';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

const PERIODS = [7, 30, 90];
const TZ = Intl.DateTimeFormat().resolvedOptions().timeZone;
const avgText = (a) => (a === null ? '—' : Number(a).toFixed(1));

const LEGEND = (
  <>
    <span className="legend-item"><span className="chart-key" style={{ background: 'var(--viz-good)' }} aria-hidden="true" />4–5 stars</span>
    <span className="legend-item"><span className="chart-key" style={{ background: 'var(--viz-bad)' }} aria-hidden="true" />Below 4 stars</span>
  </>
);

export default function DashboardPage() {
  const [days, setDays] = useState(30);
  const [companyId, setCompanyId] = useState('');
  const companies = useAsync(() => must(supabase.from('companies').select('id,name').order('name')), []);
  const stats = useAsync(() => must(supabase.rpc('dashboard_stats', { p_days: days, p_company: companyId || null, p_tz: TZ })), [days, companyId]);

  const s = stats.data;
  const refreshing = stats.loading && s;

  let body = null;
  if (stats.error && !s) body = <ErrorState message={stats.error} onRetry={stats.reload} />;
  else if (!s) body = <div className="skeleton" style={{ height: 320 }} aria-busy="true" aria-label="Loading" />;
  else {
    const c = s.summary.cur;
    const p = s.summary.prev;
    const lowPct = c.total ? pct(c.low, c.total) : null;
    const prevLow = p.total ? pct(p.low, p.total) : null;
    const ctr = c.happy ? pct(c.google, c.happy) : null;
    const prevCtr = p.happy ? pct(p.google, p.happy) : null;
    const period = `last ${days} days`;
    const total = c.total;
    const rowFor = (r) => ({ name: r.name, company: r.company ?? '', responses: r.total, avg: r.total ? Number(r.avg).toFixed(1) : '—', low: r.total ? `${pct(r.low, r.total)}%` : '—' });

    // ---- Top-row cards ----
    const responsesChange = delta(c.total, p.total, { kind: 'pct', upIsGood: true, days });

    const avgRatingNum = c.avg === null ? null : Number(c.avg);
    const prevAvgNum   = p.avg === null ? null : Number(p.avg);
    const compareRows = [
      {
        label:   'Average rating',
        value:   avgText(c.avg),
        caption: 'out of 5 stars',
        change:  delta(avgRatingNum, prevAvgNum, { kind: 'abs', upIsGood: true, days }),
        fillPct: avgRatingNum !== null ? (avgRatingNum / 5) * 100 : 0,
        color:   'var(--viz-good)',
      },
      {
        label:   'Below 4 stars',
        value:   lowPct === null ? '—' : `${lowPct}%`,
        caption: `${num(c.low)} of ${num(c.total)} responses`,
        change:  delta(lowPct, prevLow, { kind: 'pp', upIsGood: false, days }),
        fillPct: lowPct ?? 0,
        color:   'var(--viz-bad)',
      },
    ];

    const ctrChange = delta(ctr, prevCtr, { kind: 'pp', upIsGood: true, days });

    body = (
      <div style={{ opacity: refreshing ? 0.6 : 1, transition: 'opacity 0.15s' }}>
        {/* Three-column top row */}
        <div className="stats">
          <DarkStatCard
            label="Responses"
            value={num(c.total)}
            change={responsesChange}
            linkTo="/admin/feedback"
            note={period}
          />
          <CompareStatCard
            title="Quality metrics"
            rows={compareRows}
          />
          {/* KPI card: Opened Google */}
          <div className="card kpi-card" role="region" aria-label="Opened Google">
            <p className="kpi-label">Opened Google</p>
            <p className="kpi-value">{ctr === null ? '—' : `${ctr}%`}</p>
            <div className="kpi-row">
              {ctrChange && (
                <span className={`delta-chip ${ctrChange.tone}`} aria-label={ctrChange.text}>
                  {ctrChange.arrow && <span aria-hidden="true">{ctrChange.arrow}</span>}
                  {ctrChange.text}
                </span>
              )}
            </div>
            <p className="kpi-sub" style={{ marginTop: 'var(--s2)' }}>
              {num(c.google)} of {num(c.happy)} happy customers
            </p>
          </div>
        </div>

        {total === 0 ? (
          <div className="card"><EmptyState title={companyId ? `No responses for this company in the ${period}` : `No responses in the ${period}`} hint="Try a longer period." /></div>
        ) : (
          <div className="dash">
            <div className="dash-main">
              <ChartCard
                title="Responses over time"
                subtitle={`Per day, ${period}`}
                legend={LEGEND}
                chart={<TimeBars daily={s.daily} />}
                table={(
                  <DataTable
                    caption={`Responses per day, ${period}`}
                    columns={[{ key: 'day', label: 'Day' }, { key: 'high', label: '4–5 stars', numeric: true }, { key: 'low', label: 'Below 4 stars', numeric: true }]}
                    rows={s.daily.map((d) => ({ day: fmtDayLong(d.day), high: d.high, low: d.low }))}
                  />
                )}
              />
              <div className="dash-side">
                <ChartCard
                  title="Rating mix"
                  subtitle={`All ${num(total)} responses`}
                  chart={<RatingMix mix={s.mix} />}
                  table={(
                    <DataTable
                      caption={`Responses by rating, ${period}`}
                      columns={[{ key: 'rating', label: 'Rating' }, { key: 'n', label: 'Responses', numeric: true }, { key: 'share', label: 'Share', numeric: true }]}
                      rows={[...s.mix].reverse().map((m) => ({ rating: `${m.rating} stars`, n: m.n, share: `${pct(m.n, total)}%` }))}
                    />
                  )}
                />
                <section className="card chart-card">
                  <header className="chart-head"><div><h2>Google conversion</h2><p className="small muted">Customers rating 4–5 stars</p></div></header>
                  <GoogleMeter happy={c.happy} google={c.google} />
                </section>
              </div>
            </div>

            <div className="dash-ranks">
              {!companyId && (
                <ChartCard
                  title="Companies"
                  subtitle="Average rating, lowest first. Select one to focus on it."
                  chart={<RankBars rows={s.companies} unit="company" onSelect={setCompanyId} />}
                  table={(
                    <DataTable
                      caption={`Companies, ${period}`}
                      columns={[{ key: 'name', label: 'Company' }, { key: 'responses', label: 'Responses', numeric: true }, { key: 'avg', label: 'Average', numeric: true }, { key: 'low', label: 'Below 4 stars', numeric: true }]}
                      rows={s.companies.map(rowFor)}
                    />
                  )}
                />
              )}
              <ChartCard
                title="Branches"
                subtitle="Average rating, lowest first"
                chart={<RankBars rows={s.branches} unit="branch" />}
                table={(
                  <DataTable
                    caption={`Branches, ${period}`}
                    columns={[{ key: 'name', label: 'Branch' }, { key: 'company', label: 'Company' }, { key: 'responses', label: 'Responses', numeric: true }, { key: 'avg', label: 'Average', numeric: true }, { key: 'low', label: 'Below 4 stars', numeric: true }]}
                    rows={s.branches.map(rowFor)}
                  />
                )}
              />
            </div>
          </div>
        )}
      </div>
    );
  }

  return (
    <>
      <PageHead title="Dashboard" subtitle="How customers are rating your branches." />
      <div className="dash-filters">
        <div className="tabs" role="group" aria-label="Time period">
          {PERIODS.map((d) => <button key={d} type="button" aria-pressed={days === d} onClick={() => setDays(d)}>Last {d} days</button>)}
        </div>
        <label className="field dash-company">
          <span className="sr-only">Company</span>
          <select className="select" value={companyId} onChange={(e) => setCompanyId(e.target.value)}>
            <option value="">All companies</option>
            {companies.data?.map((co) => <option key={co.id} value={co.id}>{co.name}</option>)}
          </select>
        </label>
      </div>
      {body}
    </>
  );
}
