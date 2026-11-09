import { useState } from 'react';
import { Link } from 'react-router-dom';
import CompanyForm from './CompanyForm';
import ConfirmDialog from '../ui/ConfirmDialog';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function CompaniesPage() {
  const { data, error, loading, reload } = useAsync(async () => {
    const [companies, categories] = await Promise.all([
      must(supabase.from('companies').select('id,name,category_id,is_active').order('name')) ,
      must(supabase.from('categories').select('id,name,description,is_active').order('name')) ,
    ]);
    return { companies, categories };
  }, []);
  const [editing, setEditing] = useState(null);
  const [toggling, setToggling] = useState(null);
  const catName = (id) => data?.categories.find((c) => c.id === id)?.name ?? '—';

  return (
    <>
      <PageHead title="Companies" subtitle="Each company is a separate tenant with its own branches and login.">
        <button type="button" className="btn primary" disabled={!data?.categories.length} onClick={() => setEditing('new')}>New company</button>
      </PageHead>

      {loading && <ListSkeleton />}
      {error && <ErrorState message={error} onRetry={reload} />}
      {data && !data.categories.length && <EmptyState title="Create a category first" hint="Every company belongs to one category." />}
      {data && data.categories.length > 0 && data.companies.length === 0 && <EmptyState title="No companies yet" />}
      <div className="list">
        {data?.companies.map((c) => (
          <div key={c.id} className={`item${c.is_active ? '' : ' dim'}`}>
            <div>
              <div className="title">{c.name} {!c.is_active && <span className="pill off">Archived</span>}</div>
              <div className="muted small">{catName(c.category_id)}</div>
            </div>
            <div className="actions">
              <Link className="btn sm primary" to={`/admin/companies/${c.id}`}>Branches &amp; logins</Link>
              <button type="button" className="btn sm" onClick={() => setEditing(c)}>Edit</button>
              <button type="button" className="btn sm" onClick={() => setToggling(c)}>{c.is_active ? 'Archive' : 'Restore'}</button>
            </div>
          </div>
        ))}
      </div>

      {editing && data && <CompanyForm company={editing === 'new' ? null : editing} categories={data.categories} onSaved={reload} onClose={() => setEditing(null)} />}
      {toggling && (
        <ConfirmDialog
          title={toggling.is_active ? `Archive ${toggling.name}?` : `Restore ${toggling.name}?`}
          message={toggling.is_active
            ? 'All feedback links for this company stop working until it is restored. Existing feedback is kept.'
            : 'Feedback links for this company will work again.'}
          confirmLabel={toggling.is_active ? 'Archive' : 'Restore'}
          onClose={() => setToggling(null)}
          onConfirm={async () => { await must(supabase.from('companies').update({ is_active: !toggling.is_active }).eq('id', toggling.id).select()); reload(); }}
        />
      )}
    </>
  );
}
