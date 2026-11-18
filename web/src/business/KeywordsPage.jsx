import { useState } from 'react';
import BranchKeywordsPicker from '../shared/BranchKeywordsPicker';
import CompanyKeywordsPicker from '../shared/CompanyKeywordsPicker';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';
import { useAsync } from '../lib/useAsync';

export default function KeywordsPage() {
  const { data, error, loading, reload } = useAsync(async () => {
    const [branches, companies] = await Promise.all([
      must(supabase.from('branches').select('id,company_id,name,is_active').order('name')),
      must(supabase.from('companies').select('id,name,subcategories(category_id)')),
    ]);
    return { branches, companyId: companies[0]?.id ?? null, categoryId: companies[0]?.subcategories?.category_id ?? null };
  }, []);
  const [open, setOpen] = useState(null);
  const [resets, setResets] = useState({}); // branch id -> remount counter after an override is cleared
  const [clearing, setClearing] = useState(null);
  const [clearError, setClearError] = useState(null);

  async function clearOverride(id) {
    setClearing(id);
    setClearError(null);
    const { error: err } = await supabase.rpc('set_branch_keywords', { p_branch_id: id, p_keyword_ids: [] });
    setClearing(null);
    if (err) { setClearError({ id, text: errorMessage(err) }); return; }
    setResets((r) => ({ ...r, [id]: (r[id] ?? 0) + 1 }));
  }

  if (loading && !data) return <ListSkeleton />;
  if (error || !data) return <ErrorState message={error ?? 'Could not load branches'} onRetry={reload} />;

  return (
    <>
      <PageHead title="Keywords" subtitle="Choose up to 10 keywords customers can pick, for the whole company and optionally per branch." />
      {data.companyId && (
        <div className="item bkw-card">
          <div className="title">Company keywords</div>
          <p className="muted small ckw-note">Used by every branch that has no override of its own.</p>
          <CompanyKeywordsPicker companyId={data.companyId} categoryId={data.categoryId} />
        </div>
      )}
      {data.branches.length > 0 && <h2 className="ckw-head">Branch override</h2>}
      {data.branches.length === 0 && <EmptyState title="No branches yet" hint="Keywords can be chosen once a branch exists." />}
      <div className="list">
        {data.branches.map((b) => (
          <div key={b.id} className={`item bkw-card${b.is_active ? '' : ' dim'}`}>
            <div className="bkw-card-head">
              <div className="title">{b.name} {!b.is_active && <span className="pill off">Archived</span>}</div>
              <button type="button" className="btn sm" aria-expanded={open === b.id} onClick={() => setOpen(open === b.id ? null : b.id)}>
                {open === b.id ? 'Hide' : 'Set override'}
              </button>
            </div>
            {open === b.id && (<>
              <p className="muted small ckw-note">Leave empty to use the company's keywords.</p>
              <BranchKeywordsPicker key={resets[b.id] ?? 0} branchId={b.id} categoryId={data.categoryId} />
              <div className="bkw-foot">
                <button type="button" className="btn sm" onClick={() => clearOverride(b.id)} disabled={clearing === b.id}>{clearing === b.id ? 'Clearing…' : 'Clear override'}</button>
                {clearError?.id === b.id && <span className="alert" role="alert">{clearError.text}</span>}
              </div>
            </>)}
          </div>
        ))}
      </div>
    </>
  );
}
