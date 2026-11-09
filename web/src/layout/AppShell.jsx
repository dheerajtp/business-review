import { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import TopBar from './TopBar';
import NewFeedbackProvider from '../notify/NewFeedbackProvider';

const KEY = 'sidebar-collapsed';
const readCollapsed = () => { try { return localStorage.getItem(KEY) === '1'; } catch { return false; } };

export default function AppShell() {
  const [open, setOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const toggleCollapsed = () => {
    setCollapsed(!collapsed);
    try { localStorage.setItem(KEY, collapsed ? '0' : '1'); } catch { /* private mode: just don't remember it */ }
  };
  const { pathname } = useLocation();

  // Lets the stylesheet use the denser admin text size without touching the customer form.
  useEffect(() => {
    document.documentElement.classList.add('app-shell');
    return () => document.documentElement.classList.remove('app-shell');
  }, []);
  useEffect(() => setOpen(false), [pathname]);
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open]);

  return (
    <NewFeedbackProvider>
      <div className={`shell${collapsed ? ' collapsed' : ''}`}>
        <Sidebar open={open} collapsed={collapsed} onToggleCollapse={toggleCollapsed} onNavigate={() => setOpen(false)} />
        {open && <div className="scrim" onClick={() => setOpen(false)} />}
        <div className="content">
          <TopBar menuOpen={open} onMenu={() => setOpen(!open)} />
          <main className="main"><Outlet /></main>
        </div>
      </div>
    </NewFeedbackProvider>
  );
}
