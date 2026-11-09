export default function ListSkeleton({ rows = 3 }) {
  return (
    <div className="list" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => <div key={i} className="skeleton" style={{ height: 68 }} />)}
    </div>
  );
}
