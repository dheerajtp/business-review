import { useMemo, useState } from 'react';
import FormPreview from './FormPreview';
import QuestionForm from './QuestionForm';
import QuestionRow from './QuestionRow';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';
import { SOFT_QUESTION_LIMIT } from '../lib/types';

const COLS = 'id,category_id,company_id,text,type,options,is_required,sort_order,is_active,created_at';
const byOrder = (a, b) => a.sort_order - b.sort_order;

export default function QuestionsPage() {
  const { data, error, loading, reload } = useAsync(async () => {
    const [categories, companies, questions] = await Promise.all([
      must(supabase.from('categories').select('id,name,description,is_active').order('name')) ,
      must(supabase.from('companies').select('id,name,category_id,is_active').order('name')) ,
      must(supabase.from('questions').select(COLS)) ,
    ]);
    return { categories, companies, questions };
  }, []);

  const [categoryId, setCategoryId] = useState('');
  const [companyId, setCompanyId] = useState(''); // '' = the whole category
  const [editing, setEditing] = useState(null);

  const catId = categoryId || data?.categories[0]?.id || '';
  const companies = useMemo(() => data?.companies.filter((c) => c.category_id === catId) ?? [], [data, catId]);
  const scopeCompany = companies.find((c) => c.id === companyId);

  const categoryQs = useMemo(() => (data?.questions ?? []).filter((q) => q.category_id === catId && !q.company_id).sort(byOrder), [data, catId]);
  const companyQs = useMemo(() => (data?.questions ?? []).filter((q) => scopeCompany && q.company_id === scopeCompany.id).sort(byOrder), [data, scopeCompany]);
  const editable = scopeCompany ? companyQs : categoryQs;
  const shown = scopeCompany ? [...categoryQs.map((q) => ({ q, locked: true })), ...companyQs.map((q) => ({ q, locked: false }))] : categoryQs.map((q) => ({ q, locked: false }));

  const activeCount = shown.filter((s) => s.q.is_active).length;
  const preview = {
    branch_name: 'Sample Branch',
    company_name: scopeCompany?.name ?? data?.categories.find((c) => c.id === catId)?.name ?? 'Your company',
    google_place_id: 'preview',
    questions: shown.filter((s) => s.q.is_active).map(({ q }) => ({ id: q.id, text: q.text, type: q.type, options: q.options, is_required: q.is_required })),
  };

  async function toggle(q) {
    await must(supabase.from('questions').update({ is_active: !q.is_active }).eq('id', q.id).select());
    reload();
  }
  async function move(q, dir) {
    const i = editable.findIndex((x) => x.id === q.id);
    const other = editable[i + dir];
    if (!other) return;
    // Re-number the whole list so ties in sort_order can never block a swap.
    const next = [...editable];
    next[i] = other; next[i + dir] = q;
    await Promise.all(next.map((x, idx) => must(supabase.from('questions').update({ sort_order: idx + 1 }).eq('id', x.id).select())));
    reload();
  }

  if (loading && !data) return <ListSkeleton />;
  if (error || !data) return <ErrorState message={error ?? 'Could not load'} onRetry={reload} />;
  if (!data.categories.length) return <EmptyState title="Create a category first" hint="Questions belong to a category." />;

  return (
    <>
      <PageHead title="Questions" subtitle="Set up what customers are asked. Add company-only questions on top of the category set.">
        <button type="button" className="btn primary" onClick={() => setEditing('new')}>New question</button>
      </PageHead>

      <div className="filters" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
        <label className="field"><span className="label">Category</span>
          <select className="select" value={catId} onChange={(e) => { setCategoryId(e.target.value); setCompanyId(''); }}>
            {data.categories.map((c) => <option key={c.id} value={c.id}>{c.name}{c.is_active ? '' : ' (archived)'}</option>)}
          </select>
        </label>
        <label className="field"><span className="label">Applies to</span>
          <select className="select" value={companyId} onChange={(e) => setCompanyId(e.target.value)}>
            <option value="">Every company in this category</option>
            {companies.map((c) => <option key={c.id} value={c.id}>Only {c.name}</option>)}
          </select>
        </label>
      </div>

      {activeCount > SOFT_QUESTION_LIMIT && (
        <p className="alert" role="status" style={{ background: 'var(--warn-soft)', color: 'inherit', marginBottom: 16 }}>
          Customers will see {activeCount} questions. More than {SOFT_QUESTION_LIMIT} tends to lower completion on mobile.
        </p>
      )}

      <div className="split">
        <div>
          {shown.length === 0 && <EmptyState title="No questions yet" hint="Customers will still be able to rate and comment." />}
          <div className="list">
            {shown.map(({ q, locked }) => {
              const i = editable.findIndex((x) => x.id === q.id);
              return (
                <QuestionRow key={q.id} q={q} locked={locked} canUp={i > 0} canDown={i >= 0 && i < editable.length - 1}
                  onEdit={() => setEditing(q)} onMove={(d) => void move(q, d)} onToggle={() => void toggle(q)} />
              );
            })}
          </div>
        </div>
        <FormPreview key={`${catId}-${companyId}-${preview.questions.map((q) => q.id + q.text).join('|')}`} form={preview} />
      </div>

      {editing && (
        <QuestionForm
          categoryId={catId}
          companyId={scopeCompany?.id ?? null}
          question={editing === 'new' ? null : editing}
          nextOrder={Math.max(0, ...editable.map((q) => q.sort_order)) + 1}
          onSaved={reload}
          onClose={() => setEditing(null)}
        />
      )}
    </>
  );
}
