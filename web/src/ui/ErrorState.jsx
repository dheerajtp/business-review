
export default function ErrorState({ message, onRetry }) {
  return (
    <div className="alert" role="alert">
      <p>{message}</p>
      {onRetry && <button type="button" className="btn sm" style={{ marginTop: 8 }} onClick={onRetry}>Try again</button>}
    </div>
  );
}
