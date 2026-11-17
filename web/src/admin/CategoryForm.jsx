import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { taxonomyError } from './saveError';

export default function CategoryForm({ category, nextOrder, onSaved, onClose }) {
  const [name, setName] = useState(category?.name ?? '');
  const [description, setDescription] = useState(category?.description ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const row = { name: name.trim(), description: description.trim() || null };
    try {
      await must(category
        ? supabase.from('categories').update(row).eq('id', category.id).select()
        : supabase.from('categories').insert({ ...row, sort_order: nextOrder }).select());
      onSaved();
      onClose();
    } catch (err) { setError(taxonomyError(err)); setBusy(false); }
  }

  return (
    <Modal title={category ? 'Edit category' : 'New category'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Name"><input className="input" required maxLength={80} placeholder="e.g. Food & drink, Retail, Health" value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <Field label="Description" hint="Internal note, not shown to customers."><textarea className="textarea" maxLength={500} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
