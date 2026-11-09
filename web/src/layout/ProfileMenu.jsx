import { useRef, useState } from 'react';
import NavIcon from './NavIcon';
import { useAuth } from '../auth/AuthContext';
import { useDismiss } from '../lib/useDismiss';

export default function ProfileMenu() {
  const [open, setOpen] = useState(false);
  const box = useRef(null);
  const auth = useAuth();
  useDismiss(box, open, () => setOpen(false));
  const initials = (auth.email ?? '?').slice(0, 2).toUpperCase();
  const role = auth.profile?.role === 'super_admin' ? 'Super admin' : 'Business admin';

  return (
    <div className="menu-wrap" ref={box}>
      <button type="button" className="profile-btn" aria-label="Account menu" aria-haspopup="true" aria-expanded={open} onClick={() => setOpen(!open)}>
        <span className="avatar" aria-hidden="true">{initials}</span>
        <NavIcon name="chevron" />
      </button>
      {open && (
        <div className="popover profile" role="group" aria-label="Account">
          <div className="profile-head">
            <span className="avatar big" aria-hidden="true">{initials}</span>
            <div>
              <p className="profile-email">{auth.email}</p>
              <p className="small muted">{role}</p>
            </div>
          </div>
          <button type="button" className="pop-item" onClick={() => void auth.signOut()}>
            <NavIcon name="signout" />
            <span>Sign out</span>
          </button>
        </div>
      )}
    </div>
  );
}
