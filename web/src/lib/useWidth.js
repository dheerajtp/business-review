import { useEffect, useRef, useState } from 'react';

/** Returns [ref, width]: the rendered width of the referenced element, kept current on resize. */
export function useWidth() {
  const ref = useRef(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    const ro = new ResizeObserver(([entry]) => setWidth(Math.round(entry.contentRect.width)));
    ro.observe(el);
    setWidth(Math.round(el.getBoundingClientRect().width));
    return () => ro.disconnect();
  }, []);
  return [ref, width];
}
