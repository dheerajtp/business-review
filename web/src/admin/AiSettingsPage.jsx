import { useState } from 'react';
import ConfirmDialog from '../ui/ConfirmDialog';
import ErrorState from '../ui/ErrorState';
import Field from '../ui/Field';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';
import { useAsync } from '../lib/useAsync';

const PROVIDERS = [
  { id: 'gemini', name: 'Gemini' },
  { id: 'anthropic', name: 'Claude (Anthropic)' },
  { id: 'openai', name: 'OpenAI (GPT)', url: 'optional' },
  { id: 'custom', name: 'Custom (OpenAI-compatible)', url: 'required' },
];

const TEST_REASONS = {
  no_key: 'Save a key first.',
  auth: 'The provider rejected the key.',
  model: 'The model name or base URL looks wrong.',
  network: "Couldn't reach the provider.",
  timeout: 'The provider took too long.',
  quota: "The provider says this account has no credit or has hit its quota or rate limit. Add credit or check limits in the provider's console, or switch provider.",
  unavailable: 'The provider is temporarily unavailable. Try again in a minute.',
  empty: 'The provider returned no text. Try a different model.',
};

// Provider status and message are plain text for the Super Admin; never rendered as HTML.
function failText(data) {
  const base = TEST_REASONS[data?.reason] ?? 'Test failed.';
  const extra = [data?.status ? `HTTP ${data.status}` : '', data?.detail ?? ''].filter(Boolean).join(': ');
  return extra ? `${base} (${extra})` : base;
}

function invokeError(error) {
  // The call itself failed (not a provider reason). Say why, using only the HTTP status.
  const status = error.context?.status;
  return status === 404 ? "The test function isn't deployed yet. Run: npx supabase functions deploy test-ai"
    : status === 401 || status === 403 ? 'Not allowed. Sign in again as Super Admin.'
    : status === 500 ? "The server couldn't load this provider. Check that the latest database migration is applied."
    : status ? `Test failed (HTTP ${status}).`
    : "Couldn't reach the test function. Check your connection and that it is deployed.";
}

function rpcError(e) {
  const m = errorMessage(e);
  if (m === 'forbidden') return 'Only a Super Admin can change this.';
  if (m.includes('provider not tested')) return 'Run Test successfully first.';
  if (m.includes('save the provider first')) return 'Save the provider first.';
  if (m.includes('provider has no key')) return 'Save a key for this provider first.';
  if (m.includes('invalid base url')) return 'Use a public https address (no localhost, IP addresses or internal hosts).';
  if (m.includes('invalid model id')) return 'Use letters, numbers and . _ : / - only.';
  if (m.includes('synced models cannot be removed')) return "Loaded models can't be removed; they refresh with Load models.";
  if (m.includes('model in use')) return 'That model is selected for this provider.';
  return m;
}

// Dropdown options: available models, plus the saved value when it is missing or unavailable.
function modelOptions(rows, saved) {
  const opts = rows.filter((r) => r.is_available).map((r) => ({ id: r.model_id, label: r.model_id }));
  if (saved && !opts.some((o) => o.id === saved)) {
    const known = rows.some((r) => r.model_id === saved);
    opts.push({ id: saved, label: `${saved} ${known ? '(unavailable)' : '(not in list)'}` });
  }
  return opts;
}

function ProviderCard({ meta, row, rows, onChanged, onModelsChanged }) {
  const [model, setModel] = useState(row?.model ?? '');
  const [fallback, setFallback] = useState(row?.fallback_model ?? '');
  const [baseUrl, setBaseUrl] = useState(row?.base_url ?? '');
  const [key, setKey] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null); // { ok, text }
  const [removing, setRemoving] = useState(false);
  const [newModel, setNewModel] = useState('');
  const [modelsNote, setModelsNote] = useState(null); // { ok, text }
  const hasKey = !!row?.has_key;
  const loadDisabled = busy || !(hasKey || key) || (meta.url === 'required' && !hasKey && !baseUrl.trim());
  const tested = hasKey && !!row?.last_test_ok;
  const acceptedBusy = tested && !!row?.last_test_busy;
  const modelOpts = modelOptions(rows, model);
  const fallbackOpts = modelOptions(rows, fallback);
  const manualSelected = [...new Set([model, fallback])].filter((id) => id && rows.some((r) => r.model_id === id && r.source === 'manual'));
  const testedAt = tested && row?.last_tested_at ? new Date(row.last_tested_at).toLocaleString() : '';

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      await must(supabase.rpc('set_ai_provider', {
        p_provider: meta.id,
        p_model: model.trim(),
        p_base_url: meta.url ? baseUrl.trim() || null : null,
        p_api_key: key || null,
      }));
      await must(supabase.rpc('set_ai_fallback_model', { p_provider: meta.id, p_model: fallback.trim() || null }));
      setKey('');
      setMsg({ ok: true, text: 'Saved.' });
      onChanged();
    } catch (err) {
      setMsg({ ok: false, text: rpcError(err) });
    }
    setBusy(false);
  }

  async function test() {
    setBusy(true);
    setMsg(null);
    try {
      const { data, error } = await supabase.functions.invoke('test-ai', { body: { provider: meta.id } });
      if (error) setMsg({ ok: false, text: invokeError(error) });
      else if (data?.busy) setMsg({ ok: true, text: 'Your key and model are accepted, but the provider is busy right now. You can enable AI; requests retry automatically.' });
      else if (data?.ok) setMsg({ ok: true, text: `Works. Sample: ${data.sample}${data.model_used ? ` (model: ${data.model_used}${data.used_fallback ? ', fallback used' : ''})` : ''}` });
      else setMsg({ ok: false, text: failText(data) });
    } catch {
      setMsg({ ok: false, text: 'Test failed.' });
    }
    setBusy(false);
    onChanged();
  }

  async function loadModels() {
    setBusy(true);
    setMsg(null);
    setModelsNote(null);
    try {
      const { data, error } = await supabase.functions.invoke('test-ai', { body: { provider: meta.id, action: 'list_models', api_key: key || undefined, base_url: meta.url ? baseUrl.trim() || undefined : undefined } });
      if (error) setModelsNote({ ok: false, text: invokeError(error) });
      else if (data?.ok) {
        const count = Array.isArray(data.models) ? data.models.filter((m) => typeof m === 'string').length : 0;
        setModelsNote({ ok: data.stored !== false, text: data.stored === false ? "Loaded, but couldn't be saved for next time." : `${count} models loaded` });
        onModelsChanged();
      } else setModelsNote({ ok: false, text: failText(data) });
    } catch {
      setModelsNote({ ok: false, text: 'Could not load models.' });
    }
    setBusy(false);
  }

  async function addModel() {
    const id = newModel.trim();
    if (!id) return;
    setBusy(true);
    setMsg(null);
    try {
      await must(supabase.rpc('add_ai_model', { p_provider: meta.id, p_model_id: id, p_label: null }));
      setModel(id);
      setNewModel('');
      onModelsChanged();
    } catch (err) {
      setMsg({ ok: false, text: rpcError(err) });
    }
    setBusy(false);
  }

  async function removeModel(id) {
    setBusy(true);
    setMsg(null);
    try {
      await must(supabase.rpc('remove_ai_model', { p_provider: meta.id, p_model_id: id }));
      if (model === id) setModel('');
      if (fallback === id) setFallback('');
      onModelsChanged();
    } catch (err) {
      setMsg({ ok: false, text: rpcError(err) });
    }
    setBusy(false);
  }

  return (
    <form className="card ai-card" onSubmit={save}>
      <div className="ai-head">
        <h2 className="ai-title">{meta.name}</h2>
        <span className="aig-pills">
          <span className={`pill${hasKey ? '' : ' off'}`}>{hasKey ? 'Key saved' : 'No key'}</span>
          {hasKey && <span className={`pill${tested ? '' : ' off'}`}>{tested ? `${acceptedBusy ? 'Accepted, provider busy' : 'Tested OK'}${testedAt ? ` · ${testedAt}` : ''}` : 'Not tested'}</span>}
        </span>
      </div>
      <Field label="Model" hint={modelsNote?.text}>
        <select className="select" value={model} required onChange={(e) => setModel(e.target.value)}>
          <option value="" disabled>Select a model…</option>
          {modelOpts.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
        </select>
      </Field>
      <Field label="Fallback model (optional)">
        <select className="select" value={fallback} onChange={(e) => setFallback(e.target.value)}>
          <option value="">None</option>
          {fallbackOpts.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
        </select>
      </Field>
      {!rows.some((r) => r.is_available) && (
        <p className="hint">{!hasKey && !key ? 'Paste your API key, then click Load models.' : 'Click Load models to fill this list, or add a model name.'}</p>
      )}
      <div className="aim-add">
        <input
          className="input"
          value={newModel}
          maxLength={100}
          aria-label="Model name"
          onChange={(e) => setNewModel(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addModel(); } }}
        />
        <button type="button" className="btn" disabled={busy || !newModel.trim()} onClick={addModel}>Add model</button>
        {manualSelected.map((id) => (
          <button key={id} type="button" className="btn danger" disabled={busy} onClick={() => removeModel(id)}>Remove {id}</button>
        ))}
      </div>
      {meta.url && (
        <Field label={meta.url === 'required' ? 'Base URL' : 'Base URL (optional)'}>
          <input className="input" type="url" value={baseUrl} maxLength={300} required={meta.url === 'required'} placeholder="https://api.openai.com/v1" onChange={(e) => setBaseUrl(e.target.value)} />
        </Field>
      )}
      <Field label="API key" hint={hasKey ? `Saved, ending ${row.key_hint}` : undefined}>
        <input className="input" type="password" autoComplete="off" maxLength={400} value={key} placeholder={hasKey ? 'Leave empty to keep the saved key' : 'Paste the API key'} onChange={(e) => setKey(e.target.value)} />
      </Field>
      {msg && <p className={`alert${msg.ok ? ' ok' : ''}`} role={msg.ok ? 'status' : 'alert'}>{msg.text}</p>}
      <div className="ai-actions">
        <button type="submit" className="btn primary" disabled={busy || !model} title={!busy && !model ? 'Pick a model first' : undefined}>{busy ? 'Working…' : 'Save'}</button>
        <button type="button" className="btn" disabled={busy || !hasKey} title={!busy && !hasKey ? 'Save an API key first' : undefined} onClick={test}>Test</button>
        <button type="button" className="btn" disabled={loadDisabled} title={loadDisabled && !busy ? (meta.url === 'required' && !hasKey && key && !baseUrl.trim() ? 'Enter the Base URL first' : 'Paste an API key first') : undefined} onClick={loadModels}>Load models</button>
        {hasKey && <button type="button" className="btn danger" disabled={busy} onClick={() => setRemoving(true)}>Remove key</button>}
      </div>
      {removing && (
        <ConfirmDialog
          title={`Remove the ${meta.name} key?`}
          message="AI reviews will be switched off if this is the active provider."
          confirmLabel="Remove key"
          onClose={() => setRemoving(false)}
          onConfirm={async () => {
            try { await must(supabase.rpc('clear_ai_provider_key', { p_provider: meta.id })); } catch (err) { throw new Error(rpcError(err)); }
            setKey('');
            onChanged();
          }}
        />
      )}
    </form>
  );
}

function GlobalSettings({ data, onChanged }) {
  const [active, setActive] = useState(data.active_provider ?? '');
  const [enabled, setEnabled] = useState(!!data.is_enabled);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null);
  const withKey = PROVIDERS.filter((p) => data.providers?.find((r) => r.provider === p.id)?.has_key);
  const activeHasKey = withKey.some((p) => p.id === active);
  const activeTested = activeHasKey && !!data.providers?.find((r) => r.provider === active)?.last_test_ok;

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      await must(supabase.rpc('set_ai_settings', {
        p_active_provider: active,
        p_is_enabled: enabled && activeTested,
      }));
      setMsg({ ok: true, text: 'Saved.' });
      onChanged();
    } catch (err) {
      setMsg({ ok: false, text: rpcError(err) });
    }
    setBusy(false);
  }

  return (
    <form className="card ai-card" onSubmit={save}>
      <h2 className="ai-title">Settings</h2>
      <Field label="Active provider" hint={withKey.length ? undefined : 'Save a key for a provider below first.'}>
        <select className="select" value={active} onChange={(e) => setActive(e.target.value)}>
          {!activeHasKey && <option value="">Choose a provider</option>}
          {withKey.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
      </Field>
      <div className="field">
        <label className="check">
          <input type="checkbox" checked={enabled && activeTested} disabled={!activeTested} onChange={(e) => setEnabled(e.target.checked)} />
          <span>Enable AI reviews</span>
        </label>
        {!activeHasKey && <span className="hint">Choose a provider that has a saved key to turn this on.</span>}
        {activeHasKey && !activeTested && <span className="hint aig-hint">Run Test successfully on the active provider first.</span>}
        <span className="hint">Set a spending or quota limit in your AI provider's console.</span>
      </div>
      {msg && <p className={`alert${msg.ok ? ' ok' : ''}`} role={msg.ok ? 'status' : 'alert'}>{msg.text}</p>}
      <div className="ai-actions">
        <button type="submit" className="btn primary" disabled={busy || !active}>{busy ? 'Working…' : 'Save'}</button>
      </div>
    </form>
  );
}

const STAGES = {
  context: 'Loading branch',
  runtime: 'Loading AI settings',
  not_configured: 'AI not configured',
  provider: 'AI provider',
  empty: 'Empty reply',
};

// Everything below is rendered as plain text (React escapes it); nothing is HTML.
function ErrorLog() {
  const log = useAsync(() => must(supabase.rpc('get_ai_errors', { p_limit: 20 })), []);
  const [clearing, setClearing] = useState(false);
  const rows = Array.isArray(log.data) ? log.data : [];
  const msg = log.error === 'forbidden' ? 'Only a Super Admin can view this.' : log.error;

  return (
    <section className="card aie-card" aria-label="Recent AI errors">
      <div className="ai-head">
        <h2 className="ai-title">Recent AI errors</h2>
        <div className="ai-actions">
          <button type="button" className="btn" disabled={log.loading} onClick={log.reload}>Refresh</button>
          <button type="button" className="btn danger" disabled={log.loading || !rows.length} onClick={() => setClearing(true)}>Clear</button>
        </div>
      </div>
      {msg && <p className="alert" role="alert">{msg}</p>}
      {!msg && log.loading && !log.data && <p className="hint">Loading…</p>}
      {!msg && !log.loading && !rows.length && <p className="hint">No errors recorded.</p>}
      {!msg && rows.length > 0 && (
        <div className="aie-scroll">
          <table className="data-table aie-table">
            <thead>
              <tr><th>Time</th><th>Step</th><th>Provider / model</th><th>Kind</th><th>HTTP</th><th>Detail</th></tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td>{new Date(r.created_at).toLocaleString()}</td>
                  <td>{STAGES[r.stage] ?? r.stage}</td>
                  <td>{[r.provider, r.model].filter(Boolean).join(' / ') || '-'}</td>
                  <td>{r.kind ?? '-'}</td>
                  <td>{r.status ?? '-'}</td>
                  <td className="aie-detail">{r.detail ?? '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {clearing && (
        <ConfirmDialog
          title="Clear the AI error log?"
          message="All recorded AI errors will be deleted."
          confirmLabel="Clear"
          onClose={() => setClearing(false)}
          onConfirm={async () => {
            try { await must(supabase.rpc('clear_ai_errors')); } catch (err) { throw new Error(rpcError(err)); }
            log.reload();
          }}
        />
      )}
    </section>
  );
}

export default function AiSettingsPage() {
  const s = useAsync(() => must(supabase.rpc('get_ai_settings')), []);
  const m = useAsync(() => must(supabase.rpc('list_ai_models')), []);
  const aiModels = Array.isArray(m.data) ? m.data : [];
  const d = s.data;
  const stamp = d ? JSON.stringify([d.active_provider, d.is_enabled]) : '';

  return (
    <>
      <PageHead title="AI review" subtitle="Choose the AI provider that helps customers write their review. Keys are write-only and never shown again." />
      {s.loading && !d && <ListSkeleton />}
      {s.error && <ErrorState message={s.error} onRetry={s.reload} />}
      {d && (
        <div className="ai-grid">
          <GlobalSettings key={stamp + d.providers?.map((r) => `${r.provider}${r.has_key}${r.last_test_ok}${r.last_test_busy}`).join()} data={d} onChanged={s.reload} />
          {PROVIDERS.map((p) => {
            const row = d.providers?.find((r) => r.provider === p.id);
            return <ProviderCard key={`${p.id}${row?.updated_at ?? ''}${row?.has_key ?? ''}${row?.fallback_model ?? ''}`} meta={p} row={row} rows={aiModels.filter((r) => r.provider === p.id)} onChanged={s.reload} onModelsChanged={m.reload} />;
          })}
        </div>
      )}
      <ErrorLog />
    </>
  );
}
