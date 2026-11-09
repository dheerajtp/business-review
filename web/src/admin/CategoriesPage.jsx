import { useState } from 'react';
import CategoryForm from './CategoryForm';
import ConfirmDialog from '../ui/ConfirmDialog';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function CategoriesPage() {
  const { data, error, loading, reload } = useAsync(
    () => must(supabase.from('categories').select('id,name,description,is_active').order('name')) , []);
  const [editing, setEditing] = useState(null);
  const [toggling, setToggling] = useState(null);

  return (
    <>
      <PageHead title="Categories" subtitle="Business types. Each has its own question set.">
        <button type="button" className="btn primary" onClick={() => setEditing('new')}>New category</button>
      </PageHead>

      {loading && <ListSkeleton />}
      {error && <ErrorState message={error} onRetry={reload} />}
      {data && data.length === 0 && <EmptyState title="No categories yet" hint="Create one for each type of business, such as Café or Boutique." />}
      <div className="list">
        {data?.map((c) => (
          <div key={c.id} className={`item${c.is_active ? '' : ' dim'}`}>
            <div>
              <div className="title">{c.name} {!c.is_active && <span className="pill off">Archived</span>}</div>
              {c.description && <div className="muted small">{c.description}</div>}
            </div>
            <div className="actions">
              <button type="button" className="btn sm" onClick={() => setEditing(c)}>Edit</button>
              <button type="button" className="btn sm" onClick={() => setToggling(c)}>{c.is_active ? 'Archive' : 'Restore'}</button>
            </div>
          </div>
        ))}
      </div>

      {editing && <CategoryForm category={editing === 'new' ? null : editing} onSaved={reload} onClose={() => setEditing(null)} />}
      {toggling && (
        <ConfirmDialog
          title={toggling.is_active ? `Archive ${toggling.name}?` : `Restore ${toggling.name}?`}
          message={toggling.is_active
            ? 'Feedback links for every company in this category stop working until it is restored. Existing feedback is kept.'
            : 'Feedback links for companies in this category will work again.'}
          confirmLabel={toggling.is_active ? 'Archive' : 'Restore'}
          onClose={() => setToggling(null)}
          onConfirm={async () => { await must(supabase.from('categories').update({ is_active: !toggling.is_active }).eq('id', toggling.id).select()); reload(); }}
        />
      )}
    </>
  );
}
