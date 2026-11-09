/** Read-only star display with a text alternative. */
export default function Stars({ rating }) {
  return (
    <span className="stars-inline" role="img" aria-label={`${rating} out of 5 stars`}>
      {[1, 2, 3, 4, 5].map((n) => <span key={n} className={n <= rating ? '' : 'off'} aria-hidden="true">★</span>)}
    </span>
  );
}
