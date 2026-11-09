import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

export default function CompanyForm({ company, categories, onSaved, onClose }) {
  const [name, setName] = useState(company?.name ?? '');
  const [categoryId, setCategoryId] = useState(company?.category_id ?? categories.find((c) => c.is_active)?.id ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const row = { name: name.trim(), category_id: categoryId };
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
        <Field label="Category" hint="Decides which questions customers see.">
          <select className="select" required value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            {categories.filter((c) => c.is_active || c.id === company?.category_id).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !categoryId}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
