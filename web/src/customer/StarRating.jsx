import { RATING_LABEL } from '../lib/types';

const STAR = 'M12 2.5l2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17.6 6.1 20.7l1.2-6.6L2.5 9.5l6.6-.9z';

export default function StarRating({ value, onChange, name }) {
  return (
    <fieldset style={{ border: 0, padding: 0, margin: 0 }}>
      <legend className="sr-only">Your rating, 1 to 5 stars</legend>
      <div className="stars">
        {[1, 2, 3, 4, 5].map((n) => (
          <label key={n} className={`star${n <= value ? ' on' : ''}`}>
            <input type="radio" name={name} value={n} checked={value === n} onChange={() => onChange(n)} aria-label={`${n} star${n > 1 ? 's' : ''}, ${RATING_LABEL[n]}`} />
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d={STAR} /></svg>
          </label>
        ))}
      </div>
      <p className="rating-label" aria-live="polite">{RATING_LABEL[value]}</p>
    </fieldset>
  );
}
