import { useState } from 'react';
import QuestionField from './QuestionField';
import StarRating from './StarRating';
import { isAnswered } from '../lib/types';

export default function FeedbackFormView({ form, draft, onDraft, onSubmit, submitting, error, preview }) {
  const [tried, setTried] = useState(false);
  const missing = form.questions.filter((q) => q.is_required && !isAnswered(draft.answers[q.id]));

  function submit(e) {
    e.preventDefault();
    setTried(true);
    if (draft.rating && !missing.length) onSubmit?.();
  }

  return (
    <form onSubmit={submit} noValidate className={preview ? undefined : 'cust'}>
      <header className="cust-head">
        <p className="kicker">{form.company_name} · {form.branch_name}</p>
        <h1>How was your experience?</h1>
      </header>

      <div className="stack">
        <StarRating name={preview ? 'preview-rating' : 'rating'} value={draft.rating} onChange={(rating) => onDraft({ ...draft, rating })} />

        {draft.rating > 0 && (
          <div className="stack reveal">
            {form.questions.map((q) => (
              <QuestionField
                key={q.id}
                q={q}
                value={draft.answers[q.id]}
                invalid={tried && missing.includes(q)}
                onChange={(v) => onDraft({ ...draft, answers: { ...draft.answers, [q.id]: v } })}
              />
            ))}

            <label className="field qblock">
              <span className="label">Anything else you'd like to tell us? <span className="muted small">(optional)</span></span>
              <textarea className="textarea" maxLength={2000} value={draft.comment} onChange={(e) => onDraft({ ...draft, comment: e.target.value })} />
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
        {tried && missing.length > 0 && <p className="alert" role="alert">Please answer the required questions above.</p>}
      </div>

      <div className={preview ? undefined : 'submit-bar'} style={preview ? { marginTop: 16 } : undefined}>
        <button className="btn primary block" disabled={!draft.rating || submitting}>
          {submitting ? 'Sending…' : draft.rating ? 'Submit feedback' : 'Tap a star to start'}
        </button>
      </div>
    </form>
  );
}
