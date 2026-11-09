import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { supabase } from '../lib/db';

export default function AdminLoginForm({ companyId, companyName, onCreated, onClose }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [created, setCreated] = useState(false);
  const [busy, setBusy] = useState(false);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { data, error: err } = await supabase.functions.invoke('create-business-admin', {
      body: { email: email.trim(), password, company_id: companyId },
    });
    setBusy(false);
    if (err || data?.error) {
      let msg = data?.error ;
      if (!msg && err && 'context' in err) {
        try { msg = (await (err ).context.json()).error; } catch { /* keep generic */ }
      }
      setError(msg ?? 'Could not create the login.');
    } else { setCreated(true); onCreated(); }
  }

  return (
    <Modal title={`Login for ${companyName}`} onClose={onClose}>
      {created ? (
        <>
          <p className="alert ok" role="status">Login created for {email.trim()}. Share the password with them securely.</p>
          <div className="actions"><button type="button" className="btn primary" onClick={onClose}>Done</button></div>
        </>
      ) : (
        <form className="stack" onSubmit={save}>
          <p className="muted small">This person will see only {companyName}'s feedback.</p>
          <Field label="Email"><input className="input" type="email" required autoComplete="off" value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
          <Field label="Temporary password" hint="At least 8 characters."><input className="input" type="text" required minLength={8} maxLength={72} autoComplete="off" value={password} onChange={(e) => setPassword(e.target.value)} /></Field>
          {error && <p className="alert" role="alert">{error}</p>}
          <div className="actions">
            <button type="button" className="btn" onClick={onClose}>Cancel</button>
            <button className="btn primary" disabled={busy}>{busy ? 'Creating…' : 'Create login'}</button>
          </div>
        </form>
      )}
    </Modal>
  );
}
