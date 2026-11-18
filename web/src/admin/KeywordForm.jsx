import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

const saveMessage = (err) =>
  /duplicate key|unique constraint/i.test(errorMessage(err)) ? 'That keyword already exists.' : errorMessage(err);

export default function KeywordForm({ keyword, categories, nextOrder, onSaved, onClose }) {
  const [label, setLabel] = useState(keyword?.label ?? '');
  const [categoryId, setCategoryId] = useState(keyword?.category_id ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const values = { label: label.trim(), category_id: categoryId || null };
    try {
      await must(keyword
        ? supabase.from('keywords').update(values).eq('id', keyword.id).select()
        : supabase.from('keywords').insert({ ...values, sort_order: nextOrder }).select());
      onSaved();
      onClose();
    } catch (err) { setError(saveMessage(err)); setBusy(false); }
  }

  return (
    <Modal title={keyword ? 'Edit keyword' : 'New keyword'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Keyword" hint="Shown to customers as a tappable tag."><input className="input" required maxLength={60} placeholder="e.g. Friendly staff" value={label} onChange={(e) => setLabel(e.target.value)} /></Field>
        <Field label="Category" hint="General keywords are available to every company.">
          <select className="select" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">General</option>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}{c.is_active ? '' : ' (archived)'}</option>)}
          </select>
        </Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !label.trim()}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
