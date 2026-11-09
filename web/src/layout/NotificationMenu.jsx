import { useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import NavIcon from './NavIcon';
import NotificationRow from './NotificationRow';
import { useAuth } from '../auth/AuthContext';
import { useDismiss } from '../lib/useDismiss';
import { useNewFeedback } from '../notify/NewFeedbackContext';

export default function NotificationMenu() {
  const [open, setOpen] = useState(false);
  const box = useRef(null);
  const { pathname } = useLocation();
  const isSuper = useAuth().profile?.role === 'super_admin';
  const { newCount, newLow, items, pendingRequests, markSeen } = useNewFeedback();
  const feedbackPath = isSuper ? '/admin/feedback' : '/business';
  const total = newCount + pendingRequests;
  useDismiss(box, open, () => setOpen(false));

  return (
    <div className="menu-wrap" ref={box} key={pathname}>
      <button type="button" className="icon-btn" aria-label={total ? `Notifications, ${total} new` : 'Notifications'} aria-haspopup="true" aria-expanded={open} onClick={() => setOpen(!open)}>
        <NavIcon name="bell" />
        {total > 0 && <span className={`dot${newLow > 0 ? ' bad' : ''}`} aria-hidden="true" />}
      </button>
      {open && (
        <section className="popover notif" aria-label="Notifications">
          <header className="pop-head">
            <h2>Notifications</h2>
            {newCount > 0 && <button type="button" className="link-btn" onClick={() => void markSeen()}>Mark all as read</button>}
          </header>
          {isSuper && pendingRequests > 0 && (
            <Link className="notif-req" to="/admin/requests" onClick={() => setOpen(false)}>
              {pendingRequests} question {pendingRequests === 1 ? 'request is' : 'requests are'} waiting for review
            </Link>
          )}
          {items.length === 0 && !(isSuper && pendingRequests > 0) && <p className="pop-empty">You're all caught up.</p>}
          {items.length > 0 && (
            <ul className="notif-list">
              {items.map((it) => <NotificationRow key={it.id} item={it} to={feedbackPath} onClick={() => setOpen(false)} />)}
            </ul>
          )}
          <footer className="pop-foot"><Link to={feedbackPath} onClick={() => setOpen(false)}>View all feedback</Link></footer>
        </section>
      )}
    </div>
  );
}
