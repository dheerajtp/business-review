import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

export default function BranchForm({ companyId, branch, onSaved, onClose }) {
  const [name, setName] = useState(branch?.name ?? '');
  const [placeId, setPlaceId] = useState(branch?.google_place_id ?? '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const row = { name: name.trim(), google_place_id: placeId.trim() };
    try {
      await must(branch
        ? supabase.from('branches').update(row).eq('id', branch.id).select()
        : supabase.from('branches').insert({ ...row, company_id: companyId }).select());
      onSaved();
      onClose();
    } catch (err) { setError(errorMessage(err)); setBusy(false); }
  }

  return (
    <Modal title={branch ? 'Edit branch' : 'New branch'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Branch name"><input className="input" required maxLength={120} placeholder="e.g. MG Road" value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <Field label="Google Place ID" hint="Customers are sent to this branch's Google review page. A wrong ID sends them to the wrong listing, so double-check it.">
          <input className="input mono" required maxLength={300} placeholder="ChIJ…" value={placeId} onChange={(e) => setPlaceId(e.target.value)} />
        </Field>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
