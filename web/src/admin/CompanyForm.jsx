import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

export default function CompanyForm({ company, categories, subcategories, onSaved, onClose }) {
  const current = subcategories.find((s) => s.id === company?.subcategory_id);
  const [name, setName] = useState(company?.name ?? '');
  const [categoryId, setCategoryId] = useState(current?.category_id ?? '');
  const [subcategoryId, setSubcategoryId] = useState(company?.subcategory_id ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

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
    try {
      await must(company
        ? supabase.from('companies').update(row).eq('id', company.id).select()
        : supabase.from('companies').insert(row).select());
      onSaved();
      onClose();
    } catch (err) { setError(errorMessage(err)); setBusy(false); }
  }

  return (
    <Modal title={company ? 'Edit company' : 'New company'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Company name"><input className="input" required maxLength={120} value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <Field label="Category">
          <select className="select" required value={categoryId} onChange={(e) => pickCategory(e.target.value)}>
            <option value="" disabled>Select a category</option>
            {categories.filter((c) => c.is_active || c.id === current?.category_id).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </Field>
        <Field label="Subcategory" hint="Decides which keywords customers can pick.">
          <select className="select" required disabled={!categoryId} value={subcategoryId} onChange={(e) => setSubcategoryId(e.target.value)}>
            <option value="" disabled>Select a subcategory</option>
            {subOptions.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !subcategoryId}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
