import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import KeywordChecklist from '../shared/KeywordChecklist';
import { companyKeywordsMessage, loadCompanyKeywords } from '../shared/CompanyKeywordsPicker';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

export default function CompanyForm({ company, categories, subcategories, onSaved, onClose }) {
  const current = subcategories.find((s) => s.id === company?.subcategory_id);
  const [name, setName] = useState(company?.name ?? '');
  const withActiveSub = new Set(subcategories.filter((s) => s.is_active).map((s) => s.category_id));
  const usableCategories = categories.filter((c) => (c.is_active && withActiveSub.has(c.id)) || c.id === current?.category_id);
  const [categoryId, setCategoryId] = useState(current?.category_id ?? (company ? '' : usableCategories[0]?.id ?? ''));
  const [subcategoryId, setSubcategoryId] = useState(company?.subcategory_id ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [keywordIds, setKeywordIds] = useState([]);
  const [archivedKeywords, setArchivedKeywords] = useState([]);
  const [kwLoading, setKwLoading] = useState(Boolean(company));
  const [kwFailed, setKwFailed] = useState(false);
  const [savedId, setSavedId] = useState(null); // set once the company row exists, so a retry updates instead of inserting

  useEffect(() => {
    if (!company) return undefined;
    let live = true;
    loadCompanyKeywords(company.id).then((r) => {
      if (!live) return;
      setKeywordIds(r.selected);
      setArchivedKeywords(r.archived);
      setKwLoading(false);
    }, (err) => { if (live) { setError(`Could not load keywords: ${errorMessage(err)}`); setKwFailed(true); setKwLoading(false); } });
    return () => { live = false; };
  }, [company]);

  const subOptions = subcategories.filter((s) => s.category_id === categoryId && (s.is_active || s.id === company?.subcategory_id));

  function pickCategory(id) {
    setCategoryId(id);
    setSubcategoryId('');
  }

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const row = { name: name.trim(), subcategory_id: subcategoryId };
    let companyId = savedId ?? company?.id ?? null;
    try {
      if (!companyId) {
        const rows = await must(supabase.from('companies').insert(row).select());
        companyId = rows[0].id;
        setSavedId(companyId);
      } else {
        await must(supabase.from('companies').update(row).eq('id', companyId).select());
      }
    } catch (err) { setError(errorMessage(err)); setBusy(false); return; }
    onSaved();
    const { error: kwError } = await supabase.rpc('set_company_keywords', { p_company_id: companyId, p_keyword_ids: keywordIds });
    if (kwError) {
      setError(`Company saved, but keywords could not be saved: ${companyKeywordsMessage(kwError)}. Try again.`);
      setBusy(false);
      return;
    }
    onClose();
  }

  return (
    <Modal title={company ? 'Edit company' : 'New company'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Company name"><input className="input" required maxLength={120} value={name} onChange={(e) => setName(e.target.value)} /></Field>
        {usableCategories.length === 0 ? (
          <p className="muted">Create a category with at least one subcategory first. <Link to="/admin/categories">Go to Categories</Link></p>
        ) : (<>
        <Field label="Category">
          <select className="select" required value={categoryId} onChange={(e) => pickCategory(e.target.value)}>
            <option value="" disabled>Select a category</option>
            {usableCategories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </Field>
        <Field label="Subcategory" hint="Pick the type of business.">
          <select className="select" required disabled={!categoryId} value={subcategoryId} onChange={(e) => setSubcategoryId(e.target.value)}>
            <option value="" disabled>Select a subcategory</option>
            {subOptions.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </Field>
        </>)}
        <div>
          <h3 style={{ margin: '8px 0 4px' }}>Review keywords</h3>
          <p className="muted small ckw-note">Optional. Every branch without its own list uses these.</p>
          {kwLoading
            ? <p className="muted small" role="status">Loading keywords…</p>
            : <KeywordChecklist categoryId={categoryId || null} selectedIds={keywordIds} onChange={setKeywordIds} archivedKeywords={archivedKeywords} disabled={busy} />}
        </div>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || kwLoading || kwFailed || !subcategoryId || usableCategories.length === 0}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
