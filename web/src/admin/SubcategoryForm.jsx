import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { taxonomyError } from './saveError';

export default function SubcategoryForm({ categoryId, subcategory, nextOrder, onSaved, onClose }) {
  const [name, setName] = useState(subcategory?.name ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await must(subcategory
        ? supabase.from('subcategories').update({ name: name.trim() }).eq('id', subcategory.id).select()
        : supabase.from('subcategories').insert({ category_id: categoryId, name: name.trim(), sort_order: nextOrder }).select());
      onSaved();
      onClose();
    } catch (err) { setError(taxonomyError(err)); setBusy(false); }
  }

  return (
    <Modal title={subcategory ? 'Edit subcategory' : 'New subcategory'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Name"><input className="input" required maxLength={80} placeholder="e.g. Coffee shop, Bakery" value={name} onChange={(e) => setName(e.target.value)} /></Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !name.trim()}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
