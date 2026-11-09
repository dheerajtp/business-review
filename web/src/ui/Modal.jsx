import { useEffect, useId, useRef } from 'react';
import { createPortal } from 'react-dom';

const FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])';

export default function Modal({ title, onClose, wide, children }) {
  const titleId = useId();
  const box = useRef(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    const previous = document.activeElement ;
    const first = box.current?.querySelector('input,select,textarea') ?? box.current?.querySelector(FOCUSABLE);
    first?.focus();
    document.body.style.overflow = 'hidden';

    const onKey = (e) => {
      if (e.key === 'Escape') return onCloseRef.current();
      if (e.key !== 'Tab' || !box.current) return;
      const items = [...box.current.querySelectorAll(FOCUSABLE)];
      if (!items.length) return;
      const [a, z] = [items[0], items[items.length - 1]];
      if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus(); }
      else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus(); }
    };
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
      previous?.focus();
    };
  }, []);

  return createPortal(
    <div className="backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div ref={box} className={`modal${wide ? ' wide' : ''}`} role="dialog" aria-modal="true" aria-labelledby={titleId}>
        <h2 id={titleId}>{title}</h2>
        {children}
      </div>
    </div>,
    document.body,
  );
}
