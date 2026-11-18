import { useState } from 'react';
import BranchKeywordsPicker from '../shared/BranchKeywordsPicker';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function KeywordsPage() {
  const { data, error, loading, reload } = useAsync(async () => {
    const [branches, companies] = await Promise.all([
      must(supabase.from('branches').select('id,company_id,name,is_active').order('name')),
      must(supabase.from('companies').select('id,subcategories(category_id)')),
    ]);
    return { branches, categoryId: companies[0]?.subcategories?.category_id ?? null };
  }, []);
  const [open, setOpen] = useState(null);

  if (loading && !data) return <ListSkeleton />;
  if (error || !data) return <ErrorState message={error ?? 'Could not load branches'} onRetry={reload} />;

  return (
    <>
      <PageHead title="Keywords" subtitle="Choose up to 10 keywords customers can pick for each branch." />
      {data.branches.length === 0 && <EmptyState title="No branches yet" hint="Keywords can be chosen once a branch exists." />}
      <div className="list">
        {data.branches.map((b) => (
          <div key={b.id} className={`item bkw-card${b.is_active ? '' : ' dim'}`}>
            <div className="bkw-card-head">
              <div className="title">{b.name} {!b.is_active && <span className="pill off">Archived</span>}</div>
              <button type="button" className="btn sm" aria-expanded={open === b.id} onClick={() => setOpen(open === b.id ? null : b.id)}>
                {open === b.id ? 'Hide' : 'Choose keywords'}
              </button>
            </div>
            {open === b.id && <BranchKeywordsPicker branchId={b.id} categoryId={data.categoryId} />}
          </div>
        ))}
      </div>
    </>
  );
}
