import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

// Customers get a lean entry (no router, no auth, no admin code) to keep the form fast on mobile.
const slug = window.location.pathname.match(/^\/f\/([^/]+)\/?$/)?.[1];
const root = createRoot(document.getElementById('root'));

if (slug) {
  void import('./customer/FeedbackPage').then(({ default: FeedbackPage }) =>
    root.render(<StrictMode><FeedbackPage slug={decodeURIComponent(slug)} /></StrictMode>));
} else {
  void import('./App').then(({ default: App }) => root.render(<StrictMode><App /></StrictMode>));
}
