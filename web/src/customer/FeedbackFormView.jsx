import { useState } from 'react';
import StarRating from './StarRating';
import { composeReview } from './reviewText';
import { MAX_KEYWORDS } from '../lib/types';

export default function FeedbackFormView({ form, draft, onDraft, onSubmit, submitting, error, preview }) {
  const [edited, setEdited] = useState(false);
  const keywords = form.keywords ?? [];

  // Re-compose the draft review until the customer types in the box; manual edits are never overwritten.
  function withReview(next) {
    if (edited || !next.rating) return next;
    const labels = next.keywordIds.map((id) => keywords.find((k) => k.id === id)?.label).filter(Boolean);
    return { ...next, comment: composeReview({ company: form.company_name, rating: next.rating, labels }) };
  }

  function toggle(id) {
    const on = draft.keywordIds.includes(id);
    const keywordIds = on ? draft.keywordIds.filter((x) => x !== id) : [...draft.keywordIds, id];
    onDraft(withReview({ ...draft, keywordIds }));
  }

  function submit(e) {
    e.preventDefault();
    if (draft.rating) onSubmit?.();
  }

  const full = draft.keywordIds.length >= MAX_KEYWORDS;

  return (
    <form onSubmit={submit} noValidate className={preview ? undefined : 'cust'}>
      <header className="cust-head">
        <p className="kicker">{form.company_name} · {form.branch_name}</p>
        <h1>How was your experience?</h1>
      </header>

      <div className="stack">
        <StarRating name={preview ? 'preview-rating' : 'rating'} value={draft.rating} onChange={(rating) => onDraft(withReview({ ...draft, rating }))} />

        {draft.rating > 0 && (
          <div className="stack reveal">
            {keywords.length > 0 && (
              <fieldset className="qblock">
                <legend>What stood out? <span className="muted small">(optional · up to {MAX_KEYWORDS})</span></legend>
                <div className="kw-group">
                  {keywords.map((k) => {
                    const on = draft.keywordIds.includes(k.id);
                    return (
                      <button key={k.id} type="button" className="kw-chip" aria-pressed={on} disabled={!on && full} onClick={() => toggle(k.id)}>
                        {k.label}
                      </button>
                    );
                  })}
                </div>
              </fieldset>
            )}

            <label className="field qblock">
              <span className="label">Anything else you'd like to tell us? <span className="muted small">(optional)</span></span>
              <textarea className="textarea" maxLength={2000} value={draft.comment} onChange={(e) => { setEdited(true); onDraft({ ...draft, comment: e.target.value }); }} />
            </label>

            {draft.rating < 4 && (
              <label className="field qblock">
                <span className="label">Want the manager to reach you? <span className="muted small">(optional)</span></span>
                <input className="input" maxLength={200} autoComplete="tel" placeholder="Phone or email" value={draft.contact} onChange={(e) => onDraft({ ...draft, contact: e.target.value })} />
              </label>
            )}
          </div>
        )}

        {error && <p className="alert" role="alert">{error}</p>}
      </div>

      <div className={preview ? undefined : 'submit-bar'} style={preview ? { marginTop: 16 } : undefined}>
        <button className="btn primary block" disabled={!draft.rating || submitting}>
          {submitting ? 'Sending…' : draft.rating ? 'Submit feedback' : 'Tap a star to start'}
        </button>
      </div>
    </form>
  );
}
