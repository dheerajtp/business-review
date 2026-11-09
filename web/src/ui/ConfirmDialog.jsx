import { useState } from 'react';
import Modal from './Modal';
import { errorMessage } from '../lib/format';

export default function ConfirmDialog({ title, message, confirmLabel, onConfirm, onClose }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function run() {
    setBusy(true);
    setError(null);
    try { await onConfirm(); onClose(); } catch (e) { setError(errorMessage(e)); setBusy(false); }
  }

  return (
    <Modal title={title} onClose={onClose}>
      <p>{message}</p>
      {error && <p className="alert" role="alert" style={{ marginTop: 12 }}>{error}</p>}
      <div className="actions">
        <button type="button" className="btn" onClick={onClose}>Cancel</button>
        <button type="button" className="btn danger" disabled={busy} onClick={run}>{busy ? 'Working…' : confirmLabel}</button>
      </div>
    </Modal>
  );
}
