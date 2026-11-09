import { useState } from 'react';

/** Card with a title and a Chart / Table switch, so every chart has a table twin. */
export default function ChartCard({ title, subtitle, chart, table, legend }) {
  const [asTable, setAsTable] = useState(false);
  return (
    <section className="card chart-card">
      <header className="chart-head">
        <div>
          <h2>{title}</h2>
          {subtitle && <p className="small muted">{subtitle}</p>}
        </div>
        {table && (
          <button type="button" className="btn sm ghost" aria-pressed={asTable} onClick={() => setAsTable(!asTable)}>
            {asTable ? 'Show chart' : 'Show table'}
          </button>
        )}
      </header>
      {legend && !asTable && <div className="chart-legend">{legend}</div>}
      {asTable ? table : chart}
    </section>
  );
}
