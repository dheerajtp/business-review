import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from './AuthContext';
import PasswordField from './PasswordField';
import Field from '../ui/Field';

const STAR = 'M12 2.5l2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17.6 6.1 20.7l1.2-6.6L2.5 9.5l6.6-.9z';

export default function LoginPage() {
  const auth = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  if (auth.status === 'signed_in') return <Navigate to={auth.profile?.role === 'super_admin' ? '/admin' : '/business'} replace />;

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(await auth.signIn(email.trim(), password));
    setBusy(false);
  }

  return (
    <div className="login">
      <aside className="login-aside" aria-hidden="true">
        <svg viewBox="0 0 24 24"><path d={STAR} /></svg>
        <h2>Hear from every customer.</h2>
        <p>See what your branches are doing well, and where they can do better.</p>
      </aside>
      <main className="login-main">
        <div className="login-box">
          <h1>Welcome back</h1>
          <p className="muted">Sign in to see your feedback.</p>
          <form className="card login-form" onSubmit={submit}>
            <Field label="Email">
              <input className="input" type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </Field>
            <PasswordField label="Password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
            {error && <p className="alert" role="alert">{error}</p>}
            <button className="btn primary block" style={{ minHeight: 48 }} disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
          </form>
        </div>
      </main>
    </div>
  );
}
