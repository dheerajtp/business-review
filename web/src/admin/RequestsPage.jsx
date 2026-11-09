import { useState } from 'react';
import QuestionForm from './QuestionForm';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { formatDateTime } from '../lib/format';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function RequestsPage() {
  const { data, error, loading, reload } = useAsync(async () => {
    const [requests, companies, userId] = await Promise.all([
      must(supabase.from('question_requests').select('id,company_id,text,status,created_at').order('created_at', { ascending: false })) ,
      must(supabase.from('companies').select('id,name,category_id,is_active')) ,
      supabase.auth.getUser().then((r) => r.data.user?.id ?? null),
    ]);
    return { requests, companies, userId };
  }, []);
  const [tab, setTab] = useState('pending');
  const [approving, setApproving] = useState(null);
  const [actionError, setActionError] = useState(null);

  const setStatus = (id, status) =>
    must(supabase.from('question_requests').update({ status, reviewed_by: data?.userId }).eq('id', id).select());

  async function reject(r) {
    setActionError(null);
    try { await setStatus(r.id, 'rejected'); reload(); } catch (e) { setActionError(e instanceof Error ? e.message : 'Failed'); }
  }

  if (loading && !data) return <ListSkeleton />;
  if (error || !data) return <ErrorState message={error ?? 'Could not load'} onRetry={reload} />;

  const list = data.requests.filter((r) => (tab === 'pending') === (r.status === 'pending'));
  const company = (id) => data.companies.find((c) => c.id === id);
  const approvingCompany = approving && company(approving.company_id);

  return (
    <>
      <PageHead title="Question requests" subtitle="Approving adds the question to that company's form only." />
      <div className="tabs" role="group" aria-label="Filter requests">
        <button type="button" aria-pressed={tab === 'pending'} onClick={() => setTab('pending')}>Pending ({data.requests.filter((r) => r.status === 'pending').length})</button>
        <button type="button" aria-pressed={tab === 'done'} onClick={() => setTab('done')}>Reviewed</button>
      </div>
      {actionError && <p className="alert" role="alert" style={{ marginBottom: 12 }}>{actionError}</p>}
      {list.length === 0 && <EmptyState title={tab === 'pending' ? 'No pending requests' : 'Nothing reviewed yet'} />}
      <div className="list">
        {list.map((r) => (
          <div key={r.id} className="item">
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="title">{r.text}</div>
              <div className="small muted">{company(r.company_id)?.name ?? 'Unknown company'} · {formatDateTime(r.created_at)}</div>
            </div>
            {r.status === 'pending' ? (
              <div className="actions">
                <button type="button" className="btn sm primary" onClick={() => setApproving(r)}>Approve…</button>
                <button type="button" className="btn sm" onClick={() => void reject(r)}>Reject</button>
              </div>
            ) : <span className={`pill${r.status === 'rejected' ? ' off' : ''}`}>{r.status}</span>}
          </div>
        ))}
      </div>

      {approving && approvingCompany && (
        <QuestionForm
          categoryId={approvingCompany.category_id}
          companyId={approvingCompany.id}
          question={null}
          initialText={approving.text}
          nextOrder={1000}
          onSaved={async () => { await setStatus(approving.id, 'approved'); reload(); }}
          onClose={() => setApproving(null)}
        />
      )}
    </>
  );
}
