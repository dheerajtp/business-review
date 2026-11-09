/** Hover readout. Values lead (strong), labels follow (secondary). Text is inserted as React text, never HTML. */
export default function ChartTooltip({ x, y, width, title, rows }) {
  const left = Math.min(Math.max(x, 90), Math.max(90, width - 90));
  return (
    <div className="chart-tip" role="status" style={{ left, top: Math.max(y - 10, 64) }}>
      <p className="chart-tip-title">{title}</p>
      {rows.map((r) => (
        <p key={r.label} className="chart-tip-row">
          <span className="chart-key" style={{ background: r.color }} aria-hidden="true" />
          <strong>{r.value}</strong>
          <span>{r.label}</span>
        </p>
      ))}
    </div>
  );
}
