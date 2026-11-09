import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import Field from '../ui/Field';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { errorMessage, formatDateTime } from '../lib/format';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function RequestQuestionPage() {
  const auth = useAuth();
  const { data, error, loading, reload } = useAsync(
    () => must(supabase.from('question_requests').select('id,company_id,text,status,created_at').order('created_at', { ascending: false })) , []);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState(null);
  const [sent, setSent] = useState(false);

  async function submit(e) {
    e.preventDefault();
    if (!auth.profile?.company_id || !auth.userId) return;
    setBusy(true);
    setFormError(null);
    try {
      await must(supabase.from('question_requests').insert({ company_id: auth.profile.company_id, requested_by: auth.userId, text: text.trim() }).select());
      setText('');
      setSent(true);
      reload();
    } catch (err) { setFormError(errorMessage(err)); }
    setBusy(false);
  }

  return (
    <>
      <PageHead title="Request a question" subtitle="Ask for an extra question on your customers' form. The platform team reviews it and adds it if approved." />
      <div className="two-col">
      <form className="card stack" onSubmit={submit}>
        <Field label="What would you like to ask customers?" hint="For example: “Was the parking easy to find?” Mention the answer format you'd like (rating, yes/no, choices).">
          <textarea className="textarea" required maxLength={500} value={text} onChange={(e) => { setText(e.target.value); setSent(false); }} />
        </Field>
        {formError && <p className="alert" role="alert">{formError}</p>}
        {sent && <p className="alert ok" role="status">Request sent. You can follow its status in your requests list.</p>}
        <button className="btn primary" disabled={busy || !text.trim()}>{busy ? 'Sending…' : 'Send request'}</button>
      </form>

      <section aria-labelledby="req-h">
      <h2 id="req-h">Your requests</h2>
      {loading && <ListSkeleton rows={2} />}
      {error && <ErrorState message={error} onRetry={reload} />}
      {data && data.length === 0 && <EmptyState title="No requests yet" />}
      <div className="list">
        {data?.map((r) => (
          <div key={r.id} className="item">
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="title">{r.text}</div>
              <div className="small muted">{formatDateTime(r.created_at)}</div>
            </div>
            <span className={`pill${r.status === 'pending' ? ' warn' : r.status === 'rejected' ? ' off' : ''}`}>{r.status}</span>
          </div>
        ))}
      </div>
      </section>
      </div>
    </>
  );
}
