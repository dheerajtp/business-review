import { useEffect, useState } from 'react';
import KeywordChecklist from './KeywordChecklist';
import { supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

function rpcMessage(error) {
  if (error.message === 'too many keywords') return 'You can choose up to 10 keywords.';
  if (error.message === 'unknown keyword') return 'That keyword is no longer available.';
  if (error.code === '42501' && error.message === 'forbidden') return "You can't change this branch.";
  return errorMessage(error);
}

/** Checklist that picks up to 10 library keywords for one branch. Writes only via set_branch_keywords. */
export default function BranchKeywordsPicker({ branchId, categoryId = null, onSaved }) {
  const [selected, setSelected] = useState([]); // keyword ids in pick order
  const [archived, setArchived] = useState([]); // rows for selected keywords that are no longer active
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState(null); // { ok: boolean, text: string }

  useEffect(() => {
    let live = true;
    setLoading(true);
    setLoadError(null);
    (async () => {
      const { data, error } = await supabase.from('branch_keywords').select('keyword_id,position,keywords(id,label,category_id,is_active,categories(name))').eq('branch_id', branchId).order('position');
      if (error) throw new Error(error.message);
      return data ?? [];
    })().then((picks) => {
      if (!live) return;
      setArchived(picks.filter((p) => p.keywords?.is_active === false || !p.keywords).map((p) => p.keywords ?? { id: p.keyword_id, label: 'Unavailable keyword', category_id: null, is_active: false, categories: null }));
      setSelected(picks.map((p) => p.keyword_id));
      setLoading(false);
    }, (e) => { if (live) { setLoadError(errorMessage(e)); setLoading(false); } });
    return () => { live = false; };
  }, [branchId]);

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

  return (
    <div className="bkw">
      <KeywordChecklist categoryId={categoryId} selectedIds={selected} onChange={(ids) => { setStatus(null); setSelected(ids); }} archivedKeywords={archived} />
      <div className="bkw-foot">
        <button type="button" className="btn primary" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save keywords'}</button>
        {status && <span className={status.ok ? 'small bkw-ok' : 'alert'} role={status.ok ? 'status' : 'alert'}>{status.text}</span>}
      </div>
    </div>
  );
}
