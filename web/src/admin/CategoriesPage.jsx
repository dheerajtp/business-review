import { useState } from 'react';
import CategoryForm from './CategoryForm';
import SubcategoryForm from './SubcategoryForm';
import ConfirmDialog from '../ui/ConfirmDialog';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

const nextOrder = (rows) => (rows?.length ? Math.max(...rows.map((r) => r.sort_order ?? 0)) + 1 : 1);
// Active first, then by sort_order, then by name.
const ordered = (rows, key) => [...(rows ?? [])].sort((a, b) =>
  Number(b.is_active) - Number(a.is_active) || a.sort_order - b.sort_order || a[key].localeCompare(b[key]));

/** One level of the taxonomy: a titled list with New/Edit/Archive/Restore and optional row selection. */
function Level({ title, hint, rows, labelKey, selectedId, onSelect, onNew, onEdit, onToggle, state, emptyTitle, emptyHint, newLabel }) {
  return (
    <section className="tax-col" aria-label={title}>
      <header className="tax-head">
        <div>
          <h2>{title}</h2>
          {hint && <p className="muted small">{hint}</p>}
        </div>
        <button type="button" className="btn sm primary" onClick={onNew}>{newLabel}</button>
      </header>
      {state.loading && !rows && <ListSkeleton />}
      {state.error && <ErrorState message={state.error} onRetry={state.reload} />}
      {rows && rows.length === 0 && <EmptyState title={emptyTitle} hint={emptyHint} />}
      <div className="list">
        {ordered(rows, labelKey).map((r) => (
          <div key={r.id} className={`item${r.is_active ? '' : ' dim'}${r.id === selectedId ? ' tax-selected' : ''}`}>
            {onSelect ? (
              <button type="button" className="tax-pick" aria-pressed={r.id === selectedId} onClick={() => onSelect(r.id)}>
                <span className="title">{r[labelKey]} {!r.is_active && <span className="pill off">Archived</span>}</span>
                {r.description && <span className="muted small">{r.description}</span>}
              </button>
            ) : (
              <div className="title">{r[labelKey]} {!r.is_active && <span className="pill off">Archived</span>}</div>
            )}
            <div className="actions">
              <button type="button" className="btn sm" onClick={() => onEdit(r)}>Edit</button>
              <button type="button" className="btn sm" onClick={() => onToggle(r)}>{r.is_active ? 'Archive' : 'Restore'}</button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

export default function CategoriesPage() {
  const [catId, setCatId] = useState(null);
  const [subId, setSubId] = useState(null);
  const cats = useAsync(() => must(supabase.from('categories').select('id,name,description,is_active,sort_order')), []);
  const subs = useAsync(() => (catId
    ? must(supabase.from('subcategories').select('id,name,is_active,sort_order').eq('category_id', catId))
    : Promise.resolve([])), [catId]);
  // editing: { kind: 'category'|'subcategory', row: object|null }
  const [editing, setEditing] = useState(null);
  const [toggling, setToggling] = useState(null);

  const cat = cats.data?.find((c) => c.id === catId);
  const TABLES = { category: 'categories', subcategory: 'subcategories' };
  const RELOAD = { category: cats.reload, subcategory: subs.reload };
  const name = (t) => t.row.name ?? t.row.label;
  const WARN = {
    category: 'It is hidden from company pickers until restored. Existing feedback and companies are kept.',
    subcategory: 'It is hidden from company pickers until restored. Existing feedback and companies are kept.',
  };

  return (
    <>
      <PageHead title="Categories" subtitle="Categories and the subcategories companies pick from." />
      <div className="tax-grid">
        <Level
          title="Categories" rows={cats.data} labelKey="name" state={cats}
          selectedId={catId} onSelect={(id) => { setCatId(id); setSubId(null); }}
          newLabel="New category" onNew={() => setEditing({ kind: 'category', row: null })}
          onEdit={(row) => setEditing({ kind: 'category', row })} onToggle={(row) => setToggling({ kind: 'category', row })}
          emptyTitle="No categories yet" emptyHint="Create one for each broad type of business, such as Food & drink."
        />
        {cat ? (
          <Level
            title={`Subcategories of ${cat.name}`} rows={subs.loading ? null : subs.data} labelKey="name" state={subs}
            newLabel="New subcategory" onNew={() => setEditing({ kind: 'subcategory', row: null })}
            onEdit={(row) => setEditing({ kind: 'subcategory', row })} onToggle={(row) => setToggling({ kind: 'subcategory', row })}
            emptyTitle="No subcategories yet" emptyHint="Companies pick a subcategory, such as Coffee shop."
          />
        ) : <p className="muted tax-hint">Select a category to see its subcategories.</p>}
      </div>

      {editing?.kind === 'category' && <CategoryForm category={editing.row} nextOrder={nextOrder(cats.data)} onSaved={cats.reload} onClose={() => setEditing(null)} />}
      {editing?.kind === 'subcategory' && <SubcategoryForm categoryId={catId} subcategory={editing.row} nextOrder={nextOrder(subs.data)} onSaved={subs.reload} onClose={() => setEditing(null)} />}
      {toggling && (
        <ConfirmDialog
          title={toggling.row.is_active ? `Archive ${name(toggling)}?` : `Restore ${name(toggling)}?`}
          message={toggling.row.is_active ? WARN[toggling.kind] : 'It will be available again.'}
          confirmLabel={toggling.row.is_active ? 'Archive' : 'Restore'}
          onClose={() => setToggling(null)}
          onConfirm={async () => {
            await must(supabase.from(TABLES[toggling.kind]).update({ is_active: !toggling.row.is_active }).eq('id', toggling.row.id).select());
            RELOAD[toggling.kind]();
          }}
        />
      )}
    </>
  );
}
