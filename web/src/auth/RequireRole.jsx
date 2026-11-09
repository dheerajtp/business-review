import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from './AuthContext';

/** UX guard only. RLS is what actually protects the data. */
export default function RequireRole({ role }) {
  const auth = useAuth();
  if (auth.status === 'loading') return <div className="center" role="status">Loading…</div>;
  if (auth.status === 'signed_out') return <Navigate to="/login" replace />;
  if (auth.status === 'no_profile') {
    return (
      <div className="center">
        <div>
          <h1>No access yet</h1>
          <p className="muted" style={{ margin: '8px 0 16px' }}>This account has no role assigned. Ask the platform admin to set it up.</p>
          <button type="button" className="btn" onClick={() => void auth.signOut()}>Sign out</button>
        </div>
      </div>
    );
  }
  if (auth.profile?.role !== role) return <Navigate to={auth.profile?.role === 'super_admin' ? '/admin' : '/business'} replace />;
  return <Outlet />;
}
