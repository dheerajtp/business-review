import { Link } from 'react-router-dom';
import Stars from '../ui/Stars';
import { timeAgo } from '../lib/format';

export default function NotificationRow({ item, to, onClick }) {
  return (
    <li>
      <Link className="notif-row" to={to} onClick={onClick}>
        <span className={`notif-dot${item.rating < 4 ? ' bad' : ''}`} aria-hidden="true" />
        <span className="notif-body">
          <span className="notif-top"><Stars rating={item.rating} /><span className="small muted">{item.branches?.name} · {timeAgo(item.created_at)}</span></span>
          <span className="notif-text">{item.comment || 'No comment left.'}</span>
        </span>
      </Link>
    </li>
  );
}
