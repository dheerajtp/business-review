import NavIcon from './NavIcon';
import NotificationMenu from './NotificationMenu';
import ProfileMenu from './ProfileMenu';

export default function TopBar({ menuOpen, onMenu }) {
  return (
    <header className="topbar">
      <button type="button" className="icon-btn menu-toggle" aria-label={menuOpen ? 'Close menu' : 'Open menu'} aria-expanded={menuOpen} aria-controls="sidebar" onClick={onMenu}>
        <NavIcon name={menuOpen ? 'close' : 'menu'} />
      </button>
      <div className="topbar-right">
        <NotificationMenu />
        <ProfileMenu />
      </div>
    </header>
  );
}
