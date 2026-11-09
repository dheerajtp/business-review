
export default function EmptyState({ title, hint, children }) {
  return (
    <div className="empty" role="status">
      <h3>{title}</h3>
      {hint && <p>{hint}</p>}
      {children && <div style={{ marginTop: 16 }}>{children}</div>}
    </div>
  );
}
