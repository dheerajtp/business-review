// AI provider adapters (plan 06, A6). generate() returns the raw model text.
// Errors are ProviderError with a kind only; messages never carry the URL, key or response body.
import { isValidBaseUrl, normalizeBaseUrl } from "./urlGuard.js";

export class ProviderError extends Error {
  constructor(kind, { status, detail } = {}) {
    super(`provider_${kind}`);
    this.name = "ProviderError";
    this.kind = kind; // auth | model | quota | unavailable | network | timeout | unknown
    // status/detail are for the Super Admin Test only; customer code must never read them.
    this.status = status;
    this.detail = detail;
  }
}

const statusKind = (status) => {
  if (status === 401 || status === 403) return "auth";
  if (status === 400 || status === 404) return "model";
  if (status === 429) return "quota";
  if (status >= 500) return "unavailable";
  return "unknown";
};

// Collapses whitespace, masks the key and any key= query value, caps at 200 chars.
function redact(text, key) {
  let t = String(text ?? "").replace(/\s+/g, " ").trim();
  if (key) t = t.split(key).join("***");
  t = t.replace(/([?&]key=)[^&\s"']+/gi, "$1***");
  return t.slice(0, 200);
}

async function errorDetail(res, key) {
  try {
    const text = (await res.text()).slice(0, 2000);
    let msg = text;
    try {
      const m = JSON.parse(text)?.error?.message;
      if (typeof m === "string") msg = m;
    } catch { /* not JSON: use the raw text */ }
    return redact(msg, key);
  } catch {
    return undefined;
  }
}

async function request(url, init, signal, key) {
  let res;
  try {
    res = await fetch(url, { ...init, signal, redirect: "error" });
  } catch (e) {
    throw new ProviderError(e?.name === "AbortError" || signal?.aborted ? "timeout" : "network");
  }
  if (!res.ok) {
    const detail = await errorDetail(res, key);
    throw new ProviderError(statusKind(res.status), { status: res.status, detail });
  }
  try {
    return await res.json();
  } catch (e) {
    throw new ProviderError(e?.name === "AbortError" || signal?.aborted ? "timeout" : "unknown");
  }
}

function postJson(url, headers, body, signal, key) {
  return request(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  }, signal, key);
}

function getJson(url, headers, signal, key) {
  return request(url, { method: "GET", headers }, signal, key);
}

function openaiBase(provider, base_url) {
  if (base_url == null || base_url === "") {
    if (provider === "custom") throw new ProviderError("model");
    return "https://api.openai.com/v1";
  }
  if (!isValidBaseUrl(base_url)) throw new ProviderError("model");
  return normalizeBaseUrl(base_url);
}

export async function generate({ provider, model, base_url, api_key, system, user, maxTokens = 300, signal }) {
  if (typeof model !== "string" || model === "" || typeof api_key !== "string" || api_key === "") {
    throw new ProviderError("model");
  }

  if (provider === "gemini") {
    const data = await postJson(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      { "x-goog-api-key": api_key },
      {
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: user }] }],
        generationConfig: { maxOutputTokens: Math.max(maxTokens, 1024), temperature: 0.8 },
      },
      signal,
      api_key,
    );
    const parts = data?.candidates?.[0]?.content?.parts;
    return Array.isArray(parts) ? parts.map((p) => (typeof p?.text === "string" ? p.text : "")).join("") : "";
  }

  if (provider === "anthropic") {
    const data = await postJson(
      "https://api.anthropic.com/v1/messages",
      { "x-api-key": api_key, "anthropic-version": "2023-06-01" },
      { model, max_tokens: maxTokens, system, messages: [{ role: "user", content: user }] },
      signal,
      api_key,
    );
    const content = data?.content;
    return Array.isArray(content)
      ? content.filter((c) => c?.type === "text" && typeof c.text === "string").map((c) => c.text).join("")
      : "";
  }

  if (provider === "openai" || provider === "custom") {
    const base = openaiBase(provider, base_url);
    const messages = [{ role: "system", content: system }, { role: "user", content: user }];
    const body = provider === "openai"
      ? { model, messages, max_completion_tokens: maxTokens }
      : { model, messages, max_tokens: maxTokens, temperature: 0.8 };
    const data = await postJson(`${base}/chat/completions`, { Authorization: `Bearer ${api_key}` }, body, signal, api_key);
    const text = data?.choices?.[0]?.message?.content;
    return typeof text === "string" ? text : "";
  }

  throw new ProviderError("model");
}

const sleep = (ms, signal) => new Promise((resolve) => {
  if (signal?.aborted) return resolve();
  const t = setTimeout(() => { signal?.removeEventListener("abort", done); resolve(); }, ms);
  function done() { clearTimeout(t); resolve(); }
  signal?.addEventListener("abort", done, { once: true });
});

// One provider call with its own time limit. An attempt that gets no answer in time counts as the
// provider being busy (kind "unavailable"), so it is retried and can fall back; the shared signal
// still bounds the whole operation (that abort stays kind "timeout").
async function callOnce(args, signal, attemptTimeoutMs) {
  if (!(attemptTimeoutMs > 0)) return generate({ ...args, signal });
  const ac = new AbortController();
  let attemptTimedOut = false;
  const onAbort = () => ac.abort();
  if (signal?.aborted) ac.abort(); else signal?.addEventListener("abort", onAbort, { once: true });
  const timer = setTimeout(() => { attemptTimedOut = true; ac.abort(); }, attemptTimeoutMs);
  try {
    return await generate({ ...args, signal: ac.signal });
  } catch (e) {
    if (attemptTimedOut && !signal?.aborted && e instanceof ProviderError && e.kind === "timeout") {
      throw new ProviderError("unavailable", { detail: `No answer within ${Math.round(attemptTimeoutMs / 1000)} s` });
    }
    throw e;
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", onAbort);
  }
}

// Retries provider 5xx (and attempts that get no answer in time) with backoff, then tries an
// optional fallback model once. One shared signal bounds everything.
// Returns { text, model_used, used_fallback }.
export async function generateResilient({ fallback_model, attempts = 1, delaysMs = [], attemptTimeoutMs = 0, signal, ...args }) {
  const primary = args.model;
  let last;
  for (let i = 0; i < Math.max(1, attempts); i++) {
    if (i > 0) {
      await sleep(delaysMs[i - 1] ?? 0, signal);
      if (signal?.aborted) {
        const err = new ProviderError("timeout");
        err.model = primary;
        throw err;
      }
    }
    try {
      const text = await callOnce(args, signal, attemptTimeoutMs);
      return { text, model_used: primary, used_fallback: false };
    } catch (e) {
      if (!(e instanceof ProviderError)) throw e;
      e.model = primary;
      last = e;
      if (e.kind !== "unavailable") break;
    }
  }
  const canFallback = (last.kind === "unavailable" || last.kind === "model") &&
    typeof fallback_model === "string" && fallback_model !== "" && fallback_model !== primary &&
    !signal?.aborted;
  if (!canFallback) throw last;
  try {
    const text = await callOnce({ ...args, model: fallback_model }, signal, attemptTimeoutMs);
    return { text, model_used: fallback_model, used_fallback: true };
  } catch (e) {
    if (e instanceof ProviderError) e.model = fallback_model;
    throw e;
  }
}

export async function listModels({ provider, base_url, api_key, signal }) {
  if (typeof api_key !== "string" || api_key === "") throw new ProviderError("model");
  let ids;
  if (provider === "gemini") {
    const data = await getJson(
      "https://generativelanguage.googleapis.com/v1beta/models?pageSize=100",
      { "x-goog-api-key": api_key }, signal, api_key,
    );
    ids = (Array.isArray(data?.models) ? data.models : [])
      .filter((m) => Array.isArray(m?.supportedGenerationMethods) && m.supportedGenerationMethods.includes("generateContent"))
      .map((m) => (typeof m.name === "string" ? m.name.replace(/^models\//, "") : ""));
  } else if (provider === "anthropic") {
    const data = await getJson(
      "https://api.anthropic.com/v1/models?limit=100",
      { "x-api-key": api_key, "anthropic-version": "2023-06-01" }, signal, api_key,
    );
    ids = (Array.isArray(data?.data) ? data.data : []).map((m) => m?.id);
  } else if (provider === "openai" || provider === "custom") {
    const base = openaiBase(provider, base_url);
    const data = await getJson(`${base}/models`, { Authorization: `Bearer ${api_key}` }, signal, api_key);
    ids = (Array.isArray(data?.data) ? data.data : []).map((m) => m?.id);
  } else {
    throw new ProviderError("model");
  }
  return [...new Set(ids.filter((id) => typeof id === "string" && id !== ""))].sort().slice(0, 200);
}
