import EmptyState from '../ui/EmptyState';
import { formatDateTime } from '../lib/format';

export default function LoginList({ logins, error, onAdd }) {
  if (error) return <p className="alert" role="alert">Couldn't load the logins list: {error}</p>;
  if (logins.length === 0) {
    return (
      <EmptyState title="No logins yet" hint="Create a login so this company can see its own feedback.">
        <button type="button" className="btn primary" onClick={onAdd}>Add business login</button>
      </EmptyState>
    );
  }
  return (
    <ul className="list" style={{ listStyle: 'none', margin: 0, padding: 0 }}>
      {logins.map((l) => (
        <li key={l.user_id} className="item">
          <div className="row" style={{ gap: 12 }}>
            <span className="avatar" aria-hidden="true">{l.email.slice(0, 2).toUpperCase()}</span>
            <div>
              <div className="title">{l.email}</div>
              <div className="small muted">
                Added {formatDateTime(l.created_at)} · {l.last_sign_in_at ? `last signed in ${formatDateTime(l.last_sign_in_at)}` : 'has not signed in yet'}
              </div>
            </div>
          </div>
        </li>
      ))}
    </ul>
  );
}
