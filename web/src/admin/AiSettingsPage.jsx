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
  { id: 'gemini', name: 'Gemini', model: 'gemini-2.5-flash' },
  { id: 'anthropic', name: 'Claude (Anthropic)', model: 'claude-haiku-5-5' },
  { id: 'openai', name: 'OpenAI (GPT)', model: 'gpt-4o-mini', url: 'optional' },
  { id: 'custom', name: 'Custom (OpenAI-compatible)', model: 'model name', url: 'required' },
];

const TEST_REASONS = {
  no_key: 'Save a key first.',
  auth: 'The provider rejected the key.',
  model: 'The model name or base URL looks wrong.',
  network: "Couldn't reach the provider.",
  timeout: 'The provider took too long.',
  quota: "The provider's quota or rate limit was reached. Check billing and limits in the provider's console.",
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
  if (m.includes('provider has no key')) return 'Save a key for this provider first.';
  if (m.includes('invalid base url')) return 'Use a public https address (no localhost, IP addresses or internal hosts).';
  return m;
}

function ProviderCard({ meta, row, onChanged }) {
  const [model, setModel] = useState(row?.model ?? '');
  const [baseUrl, setBaseUrl] = useState(row?.base_url ?? '');
  const [key, setKey] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null); // { ok, text }
  const [removing, setRemoving] = useState(false);
  const [models, setModels] = useState([]);
  const [modelsNote, setModelsNote] = useState(null); // { ok, text }
  const hasKey = !!row?.has_key;

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
      else if (data?.ok) setMsg({ ok: true, text: `Works. Sample: ${data.sample}` });
      else setMsg({ ok: false, text: failText(data) });
    } catch {
      setMsg({ ok: false, text: 'Test failed.' });
    }
    setBusy(false);
  }

  async function loadModels() {
    setBusy(true);
    setMsg(null);
    setModelsNote(null);
    try {
      const { data, error } = await supabase.functions.invoke('test-ai', { body: { provider: meta.id, action: 'list_models' } });
      if (error) setModelsNote({ ok: false, text: invokeError(error) });
      else if (data?.ok) {
        const list = Array.isArray(data.models) ? data.models.filter((m) => typeof m === 'string') : [];
        setModels(list);
        setModelsNote({ ok: true, text: `${list.length} models available` });
      } else setModelsNote({ ok: false, text: failText(data) });
    } catch {
      setModelsNote({ ok: false, text: 'Could not load models.' });
    }
    setBusy(false);
  }

  return (
    <form className="card ai-card" onSubmit={save}>
      <div className="ai-head">
        <h2 className="ai-title">{meta.name}</h2>
        <span className={`pill${hasKey ? '' : ' off'}`}>{hasKey ? 'Key saved' : 'No key'}</span>
      </div>
      <Field label="Model" hint={modelsNote?.text}>
        <input className="input" value={model} maxLength={100} required placeholder={meta.model} list={`models-${meta.id}`} onChange={(e) => setModel(e.target.value)} />
        <datalist id={`models-${meta.id}`}>
          {models.map((m) => <option key={m} value={m} />)}
        </datalist>
      </Field>
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
        <button type="submit" className="btn primary" disabled={busy}>{busy ? 'Working…' : 'Save'}</button>
        <button type="button" className="btn" disabled={busy || !hasKey} onClick={test}>Test</button>
        <button type="button" className="btn" disabled={busy || !hasKey} onClick={loadModels}>Load models</button>
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

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      await must(supabase.rpc('set_ai_settings', {
        p_active_provider: active,
        p_is_enabled: enabled && activeHasKey,
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
          <input type="checkbox" checked={enabled && activeHasKey} disabled={!activeHasKey} onChange={(e) => setEnabled(e.target.checked)} />
          <span>Enable AI reviews</span>
        </label>
        {!activeHasKey && <span className="hint">Choose a provider that has a saved key to turn this on.</span>}
        <span className="hint">Set a spending or quota limit in your AI provider's console.</span>
      </div>
      {msg && <p className={`alert${msg.ok ? ' ok' : ''}`} role={msg.ok ? 'status' : 'alert'}>{msg.text}</p>}
      <div className="ai-actions">
        <button type="submit" className="btn primary" disabled={busy || !active}>{busy ? 'Working…' : 'Save'}</button>
      </div>
    </form>
  );
}

export default function AiSettingsPage() {
  const s = useAsync(() => must(supabase.rpc('get_ai_settings')), []);
  const d = s.data;
  const stamp = d ? JSON.stringify([d.active_provider, d.is_enabled]) : '';

  return (
    <>
      <PageHead title="AI review" subtitle="Choose the AI provider that helps customers write their review. Keys are write-only and never shown again." />
      {s.loading && !d && <ListSkeleton />}
      {s.error && <ErrorState message={s.error} onRetry={s.reload} />}
      {d && (
        <div className="ai-grid">
          <GlobalSettings key={stamp + d.providers?.map((r) => `${r.provider}${r.has_key}`).join()} data={d} onChanged={s.reload} />
          {PROVIDERS.map((p) => {
            const row = d.providers?.find((r) => r.provider === p.id);
            return <ProviderCard key={`${p.id}${row?.updated_at ?? ''}${row?.has_key ?? ''}`} meta={p} row={row} onChanged={s.reload} />;
          })}
        </div>
      )}
    </>
  );
}
