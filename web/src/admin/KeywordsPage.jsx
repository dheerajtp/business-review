import { useState } from 'react';
import KeywordForm from './KeywordForm';
import ConfirmDialog from '../ui/ConfirmDialog';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function KeywordsPage() {
  const kws = useAsync(() => must(supabase.from('keywords').select('id,label,category_id,is_active,sort_order,categories(name)')), []);
  const cats = useAsync(() => must(supabase.from('categories').select('id,name,is_active,sort_order')), []);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all'); // all | general | archived | <category id>
  const [editing, setEditing] = useState(null); // { row: object|null }
  const [toggling, setToggling] = useState(null);

  const rows = kws.data ?? [];
  const q = search.trim().toLowerCase();
  const shown = rows
    .filter((r) => (q ? r.label.toLowerCase().includes(q) : true))
    .filter((r) => {
      if (filter === 'archived') return !r.is_active;
      if (filter === 'all') return true;
      return r.is_active && (filter === 'general' ? r.category_id === null : r.category_id === filter);
    })
    .sort((a, b) => Number(b.is_active) - Number(a.is_active) || a.sort_order - b.sort_order || a.label.localeCompare(b.label));
  const nextOrder = rows.length ? Math.max(...rows.map((r) => r.sort_order ?? 0)) + 1 : 1;
  const catList = [...(cats.data ?? [])].sort((a, b) => a.name.localeCompare(b.name));

  return (
    <>
      <PageHead title="Keywords" subtitle="The shared library of tags customers can pick. Companies choose which ones to show.">
        <button type="button" className="btn primary" onClick={() => setEditing({ row: null })}>New keyword</button>
      </PageHead>
      <div className="kwl-bar">
        <input className="input" type="search" aria-label="Search keywords" placeholder="Search keywords" value={search} onChange={(e) => setSearch(e.target.value)} />
        <select className="select" aria-label="Filter keywords" value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="all">All</option>
          <option value="general">General</option>
          {catList.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          <option value="archived">Archived</option>
        </select>
      </div>
      {kws.loading && !kws.data && <ListSkeleton />}
      {kws.error && <ErrorState message={kws.error} onRetry={kws.reload} />}
      {kws.data && shown.length === 0 && (
        <EmptyState title={rows.length ? 'No matching keywords' : 'No keywords yet'} hint={rows.length ? 'Try a different search or filter.' : 'Add short tags customers can tap, such as Friendly staff.'} />
      )}
      <div className="list">
        {shown.map((r) => (
          <div key={r.id} className={`item${r.is_active ? '' : ' dim'}`}>
            <div className="kwl-main">
              <span className="title">{r.label}</span>
              <span className="muted small">{r.categories?.name ?? 'General'}</span>
            </div>
            {!r.is_active && <span className="pill off">Archived</span>}
            <div className="actions">
              <button type="button" className="btn sm" onClick={() => setEditing({ row: r })}>Edit</button>
              <button type="button" className="btn sm" onClick={() => setToggling(r)}>{r.is_active ? 'Archive' : 'Restore'}</button>
            </div>
          </div>
        ))}
      </div>

      {editing && <KeywordForm keyword={editing.row} categories={cats.data ?? []} nextOrder={nextOrder} onSaved={kws.reload} onClose={() => setEditing(null)} />}
      {toggling && (
        <ConfirmDialog
          title={toggling.is_active ? `Archive ${toggling.label}?` : `Restore ${toggling.label}?`}
          message={toggling.is_active ? 'Customers will no longer see this keyword. Existing feedback is kept.' : 'It will be available again.'}
          confirmLabel={toggling.is_active ? 'Archive' : 'Restore'}
          onClose={() => setToggling(null)}
          onConfirm={async () => {
            await must(supabase.from('keywords').update({ is_active: !toggling.is_active }).eq('id', toggling.id).select());
            kws.reload();
          }}
        />
      )}
    </>
  );
}
