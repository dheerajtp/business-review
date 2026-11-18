import { useEffect, useState } from 'react';
import KeywordChecklist from './KeywordChecklist';
import { supabase } from '../lib/db';
import { errorMessage } from '../lib/format';

/** Friendly text for a failed set_company_keywords call. */
export function companyKeywordsMessage(error) {
  if (error.message === 'too many keywords') return 'You can choose up to 10 keywords.';
  if (error.message === 'unknown keyword') return 'That keyword is no longer available.';
  if (error.message === 'unknown company') return 'That company no longer exists.';
  if (error.code === '42501' && error.message === 'forbidden') return "You can't change this company.";
  return errorMessage(error);
}

/** Selected ids (pick order) and archived rows for a company's current keywords. Read-only select. */
export async function loadCompanyKeywords(companyId) {
  const { data, error } = await supabase.from('company_keywords').select('keyword_id,position,keywords(id,label,category_id,is_active,categories(name))').eq('company_id', companyId).order('position');
  if (error) throw new Error(error.message);
  const picks = data ?? [];
  return {
    selected: picks.map((p) => p.keyword_id),
    archived: picks.filter((p) => p.keywords?.is_active === false || !p.keywords).map((p) => p.keywords ?? { id: p.keyword_id, label: 'Unavailable keyword', category_id: null, is_active: false, categories: null }),
  };
}

/** Checklist that picks up to 10 library keywords for a company. Writes only via set_company_keywords. */
export default function CompanyKeywordsPicker({ companyId, categoryId = null, onSaved }) {
  const [selected, setSelected] = useState([]);
  const [archived, setArchived] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState(null);

  useEffect(() => {
    let live = true;
    setLoading(true);
    setLoadError(null);
    loadCompanyKeywords(companyId).then((r) => {
      if (!live) return;
      setSelected(r.selected);
      setArchived(r.archived);
      setLoading(false);
    }, (e) => { if (live) { setLoadError(errorMessage(e)); setLoading(false); } });
    return () => { live = false; };
  }, [companyId]);

  async function save() {
    setBusy(true);
    setStatus(null);
    const { error } = await supabase.rpc('set_company_keywords', { p_company_id: companyId, p_keyword_ids: selected });
    setBusy(false);
    if (error) { setStatus({ ok: false, text: companyKeywordsMessage(error) }); return; }
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
