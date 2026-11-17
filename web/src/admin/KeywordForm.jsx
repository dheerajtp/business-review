import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { taxonomyError } from './saveError';

export default function KeywordForm({ subcategoryId, keyword, nextOrder, onSaved, onClose }) {
  const [label, setLabel] = useState(keyword?.label ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await must(keyword
        ? supabase.from('keywords').update({ label: label.trim() }).eq('id', keyword.id).select()
        : supabase.from('keywords').insert({ subcategory_id: subcategoryId, label: label.trim(), sort_order: nextOrder }).select());
      onSaved();
      onClose();
    } catch (err) { setError(taxonomyError(err)); setBusy(false); }
  }

  return (
    <Modal title={keyword ? 'Edit keyword' : 'New keyword'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Keyword" hint="Shown to customers as a tappable tag."><input className="input" required maxLength={40} placeholder="e.g. Friendly staff" value={label} onChange={(e) => setLabel(e.target.value)} /></Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !label.trim()}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
