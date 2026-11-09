/** Plain table twin of a chart. columns: [{ key, label, numeric? }] */
export default function DataTable({ caption, columns, rows }) {
  return (
    <div className="table-wrap">
      <table className="data-table">
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr>{columns.map((c) => <th key={c.key} scope="col" className={c.numeric ? 'num' : undefined}>{c.label}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i}>{columns.map((c) => <td key={c.key} className={c.numeric ? 'num' : undefined}>{r[c.key]}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
