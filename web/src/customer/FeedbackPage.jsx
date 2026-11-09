import { useEffect, useState } from 'react';
import FeedbackFormView from './FeedbackFormView';
import ThankYou from './ThankYou';
import { supabase } from '../lib/supabase';
import { EMPTY_DRAFT } from '../lib/types';

export default function FeedbackPage({ slug }) {
  const [load, setLoad] = useState({ s: 'loading' });
  const [draft, setDraft] = useState(EMPTY_DRAFT);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [submissionId, setSubmissionId] = useState(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let live = true;
    setLoad({ s: 'loading' });
    supabase.rpc('get_feedback_form', { p_slug: slug }).then(({ data, error: e }) => {
      if (!live) return;
      if (e) setLoad({ s: 'error' });
      else setLoad(data ? { s: 'ready', form: data  } : { s: 'missing' });
    });
    return () => { live = false; };
  }, [slug, attempt]);

  async function submit() {
    setSubmitting(true);
    setError(null);
    const { data, error: e } = await supabase.rpc('submit_feedback', {
      p_slug: slug,
      p_rating: draft.rating,
      p_answers: draft.answers,
      p_comment: draft.comment,
      p_contact: draft.contact,
    });
    setSubmitting(false);
    if (e) setError('We could not send your feedback. Please check your connection and try again.');
    else setSubmissionId(data );
  }

  if (load.s === 'loading') {
    return (
      <div className="cust" aria-busy="true" aria-label="Loading">
        <div className="skeleton" style={{ height: 56, marginBottom: 24 }} />
        <div className="skeleton" style={{ height: 64 }} />
      </div>
    );
  }
  if (load.s === 'missing') {
    return <div className="center"><div><h1>This feedback link isn't active</h1><p className="muted" style={{ marginTop: 8 }}>Please ask the staff for help.</p></div></div>;
  }
  if (load.s === 'error') {
    return <div className="center"><div><h1>Couldn't load the form</h1><button type="button" className="btn primary" style={{ marginTop: 16 }} onClick={() => setAttempt((a) => a + 1)}>Try again</button></div></div>;
  }
  if (submissionId) return <ThankYou form={load.form} draft={draft} submissionId={submissionId} />;

  return <FeedbackFormView form={load.form} draft={draft} onDraft={setDraft} onSubmit={() => void submit()} submitting={submitting} error={error} />;
}
