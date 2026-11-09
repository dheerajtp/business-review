import { NavLink } from 'react-router-dom';
import NavIcon from './NavIcon';
import { useAuth } from '../auth/AuthContext';
import { useNewFeedback } from '../notify/NewFeedbackContext';

// [path, label, icon, end]
const SUPER = [
  ['Overview', [['/admin', 'Dashboard', 'chart', true], ['/admin/feedback', 'Feedback', 'feedback', false]]],
  ['Set up', [['/admin/questions', 'Questions', 'questions', false], ['/admin/categories', 'Categories', 'categories', false]]],
  ['Manage', [['/admin/companies', 'Companies', 'companies', false], ['/admin/requests', 'Requests', 'requests', false]]],
];
const BUSINESS = [
  ['Overview', [['/business', 'Feedback', 'feedback', true]]],
  ['Customers', [['/business/request', 'Request a question', 'add', false]]],
];

export default function Sidebar({ open, collapsed, onToggleCollapse, onNavigate }) {
  const auth = useAuth();
  const { newCount, newLow, pendingRequests } = useNewFeedback();
  const groups = auth.profile?.role === 'super_admin' ? SUPER : BUSINESS;

  return (
    <aside className={`sidebar${open ? ' open' : ''}`} id="sidebar" aria-label="Main">
      <div className="side-logo" aria-hidden="true"><NavIcon name="star" /></div>
      <nav className="side-nav">
        {groups.map(([title, links]) => (
          <div key={title} className="side-group">
            <p className="side-title">{title}</p>
            {links.map(([to, label, icon, end]) => (
              <NavLink key={to} to={to} end={end} onClick={onNavigate} data-tip={label}>
                <NavIcon name={icon} />
                <span>{label}</span>
                {icon === 'feedback' && newCount > 0 && (
                  <span className={`badge${newLow > 0 ? ' bad' : ''}`}>
                    {newCount >= 100 ? '99+' : newCount}
                    <span className="sr-only"> new{newLow > 0 ? `, ${newLow} below 4 stars` : ''}</span>
                  </span>
                )}
                {icon === 'requests' && pendingRequests > 0 && (
                  <span className="badge">{pendingRequests}<span className="sr-only"> pending</span></span>
                )}
              </NavLink>
            ))}
          </div>
        ))}
      </nav>
      <button type="button" className="side-collapse" aria-expanded={!collapsed} aria-controls="sidebar" onClick={onToggleCollapse} data-tip={collapsed ? 'Expand sidebar' : undefined}>
        <NavIcon name="collapse" />
        <span>{collapsed ? 'Expand sidebar' : 'Collapse'}</span>
      </button>
    </aside>
  );
}
