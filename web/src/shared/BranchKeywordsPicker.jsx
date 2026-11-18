import { useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

const MAX = 10;

function rpcMessage(error) {
  if (error.message === 'too many keywords') return 'You can choose up to 10 keywords.';
  if (error.message === 'unknown keyword') return 'That keyword is no longer available.';
  if (error.code === '42501' && error.message === 'forbidden') return "You can't change this branch.";
  return errorMessage(error);
}

/** Checklist that picks up to 10 library keywords for one branch. Writes only via set_branch_keywords. */
export default function BranchKeywordsPicker({ branchId, categoryId = null, onSaved }) {
  const [library, setLibrary] = useState([]);
  const [selected, setSelected] = useState([]); // keyword ids in pick order
  const [archived, setArchived] = useState({}); // id -> row for selected keywords not in the active list
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [search, setSearch] = useState('');
  const [showAll, setShowAll] = useState(false);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState(null); // { ok: boolean, text: string }

  useEffect(() => {
    let live = true;
    setLoading(true);
    setLoadError(null);
    (async () => {
      const [kw, picks] = await Promise.all([
        supabase.from('keywords').select('id,label,category_id,is_active,sort_order,categories(name)').eq('is_active', true),
        supabase.from('branch_keywords').select('keyword_id,position,keywords(id,label,category_id,is_active,categories(name))').eq('branch_id', branchId).order('position'),
      ]);
      if (kw.error) throw new Error(kw.error.message);
      if (picks.error) throw new Error(picks.error.message);
      return { kw: kw.data ?? [], picks: picks.data ?? [] };
    })().then(({ kw, picks }) => {
      if (!live) return;
      const activeIds = new Set(kw.map((k) => k.id));
      const extra = {};
      for (const p of picks) {
        if (!activeIds.has(p.keyword_id)) extra[p.keyword_id] = p.keywords ?? { id: p.keyword_id, label: 'Unavailable keyword', category_id: null, categories: null };
      }
      setLibrary(kw);
      setArchived(extra);
      setSelected(picks.map((p) => p.keyword_id));
      setLoading(false);
    }, (e) => { if (live) { setLoadError(errorMessage(e)); setLoading(false); } });
    return () => { live = false; };
  }, [branchId]);

  const q = search.trim().toLowerCase();
  const rows = useMemo(() => {
    const all = [...library, ...Object.values(archived)];
    return all
      .filter((k) => (q ? k.label.toLowerCase().includes(q) : true))
      .filter((k) => showAll || selected.includes(k.id) || k.category_id === null || k.category_id === categoryId)
      .sort((a, b) => Number(selected.includes(b.id)) - Number(selected.includes(a.id)) || (a.sort_order ?? 0) - (b.sort_order ?? 0) || a.label.localeCompare(b.label));
  }, [library, archived, q, showAll, selected, categoryId]);

  function toggle(id) {
    setStatus(null);
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : s.length < MAX ? [...s, id] : s));
  }

  async function save() {
    setBusy(true);
    setStatus(null);
    const { error } = await supabase.rpc('set_branch_keywords', { p_branch_id: branchId, p_keyword_ids: selected });
    setBusy(false);
    if (error) { setStatus({ ok: false, text: rpcMessage(error) }); return; }
    setStatus({ ok: true, text: 'Saved' });
    onSaved?.();
  }

  if (loading) return <p className="muted small" role="status">Loading keywords…</p>;
  if (loadError) return <p className="alert" role="alert">{loadError}</p>;

  const full = selected.length >= MAX;
  return (
    <div className="bkw">
      <div className="bkw-bar">
        <input className="input" type="search" aria-label="Search keywords" placeholder="Search keywords" value={search} onChange={(e) => setSearch(e.target.value)} />
        <label className="bkw-toggle"><input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} /> Show all</label>
        <span className="pill" aria-live="polite">{selected.length} / {MAX}</span>
      </div>
      {rows.length === 0 ? (
        <p className="muted small">No keywords match.</p>
      ) : (
        <ul className="bkw-list">
          {rows.map((k) => {
            const checked = selected.includes(k.id);
            return (
              <li key={k.id}>
                <label className={`bkw-row${k.is_active === false ? ' dim' : ''}`}>
                  <input type="checkbox" checked={checked} disabled={!checked && full} onChange={() => toggle(k.id)} />
                  <span className="bkw-label">{k.label}</span>
                  <span className="muted small">{k.categories?.name ?? 'General'}</span>
                  {k.is_active === false && <span className="pill off">archived</span>}
                </label>
              </li>
            );
          })}
        </ul>
      )}
      <div className="bkw-foot">
        <button type="button" className="btn primary" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save keywords'}</button>
        {status && <span className={status.ok ? 'small bkw-ok' : 'alert'} role={status.ok ? 'status' : 'alert'}>{status.text}</span>}
      </div>
    </div>
  );
}
