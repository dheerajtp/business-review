import { useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

export const MAX_KEYWORDS = 10;

/**
 * Controlled checklist of active library keywords (max 10). Holds no saved state: the parent owns `selectedIds`
 * (pick order = position). `archivedKeywords` are rows for already-selected keywords no longer in the active library.
 */
export default function KeywordChecklist({ categoryId = null, selectedIds, onChange, disabled = false, archivedKeywords = [] }) {
  const [library, setLibrary] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [search, setSearch] = useState('');
  const [showAll, setShowAll] = useState(false);

  useEffect(() => {
    let live = true;
    supabase.from('keywords').select('id,label,category_id,is_active,sort_order,categories(name)').eq('is_active', true)
      .then(({ data, error }) => {
        if (!live) return;
        if (error) setLoadError(errorMessage(error)); else setLibrary(data ?? []);
        setLoading(false);
      }, (e) => { if (live) { setLoadError(errorMessage(e)); setLoading(false); } });
    return () => { live = false; };
  }, []);

  // Rows never move when ticking/unticking: order and visibility do not depend on what is selected now.
  // Keywords that were selected at any point while this list was open stay visible (pinned), so an
  // already-saved pick from another category shows up, and unticking it does not make it disappear.
  const pinned = useRef(new Set());
  selectedIds.forEach((id) => pinned.current.add(id));

  const q = search.trim().toLowerCase();
  const rows = useMemo(() => {
    const activeIds = new Set(library.map((k) => k.id));
    const all = [...library, ...archivedKeywords.filter((k) => !activeIds.has(k.id))];
    const group = (k) => (k.category_id === categoryId && categoryId !== null ? 0 : k.category_id === null ? 1 : 2);
    return all
      .filter((k) => (q ? k.label.toLowerCase().includes(q) : true))
      .filter((k) => showAll || pinned.current.has(k.id) || k.category_id === null || k.category_id === categoryId)
      .sort((a, b) => group(a) - group(b)
        || (a.categories?.name ?? '').localeCompare(b.categories?.name ?? '')
        || (a.sort_order ?? 0) - (b.sort_order ?? 0)
        || a.label.localeCompare(b.label));
    // selectedIds is deliberately not a dependency except to pick up newly pinned ids from a late load.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [library, archivedKeywords, q, showAll, categoryId, selectedIds.length === 0]);

  function toggle(id) {
    onChange(selectedIds.includes(id) ? selectedIds.filter((x) => x !== id) : selectedIds.length < MAX_KEYWORDS ? [...selectedIds, id] : selectedIds);
  }

  if (loading) return <p className="muted small" role="status">Loading keywords…</p>;
  if (loadError) return <p className="alert" role="alert">{loadError}</p>;

  const full = selectedIds.length >= MAX_KEYWORDS;
  return (
    <div className="bkw">
      <div className="bkw-bar">
        <input className="input" type="search" aria-label="Search keywords" placeholder="Search keywords" value={search} onChange={(e) => setSearch(e.target.value)} />
        <label className="bkw-toggle"><input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} /> Show all</label>
        <span className="pill" aria-live="polite">{selectedIds.length} / {MAX_KEYWORDS}</span>
      </div>
      {rows.length === 0 ? (
        <p className="muted small">No keywords match.</p>
      ) : (
        <ul className="bkw-list">
          {rows.map((k) => {
            const checked = selectedIds.includes(k.id);
            return (
              <li key={k.id}>
                <label className={`bkw-row${k.is_active === false ? ' dim' : ''}`}>
                  <input type="checkbox" checked={checked} disabled={disabled || (!checked && full)} onChange={() => toggle(k.id)} />
                  <span className="bkw-label">{k.label}</span>
                  <span className="muted small">{k.categories?.name ?? 'General'}</span>
                  {k.is_active === false && <span className="pill off">archived</span>}
                </label>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
