// AI provider adapters (plan 06, A6). generate() returns the raw model text.
// Errors are ProviderError with a kind only; messages never carry the URL, key or response body.
import { isValidBaseUrl, normalizeBaseUrl } from "./urlGuard.js";

export class ProviderError extends Error {
  constructor(kind) {
    super(`provider_${kind}`);
    this.name = "ProviderError";
    this.kind = kind; // auth | model | quota | unavailable | network | timeout | unknown
  }
}

const statusKind = (status) => {
  if (status === 401 || status === 403) return "auth";
  if (status === 400 || status === 404) return "model";
  if (status === 429) return "quota";
  if (status >= 500) return "unavailable";
  return "unknown";
};

async function postJson(url, headers, body, signal) {
  let res;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(body),
      signal,
      redirect: "error",
    });
  } catch (e) {
    throw new ProviderError(e?.name === "AbortError" || signal?.aborted ? "timeout" : "network");
  }
  if (!res.ok) {
    try { await res.body?.cancel(); } catch { /* ignore */ }
    throw new ProviderError(statusKind(res.status));
  }
  try {
    return await res.json();
  } catch (e) {
    throw new ProviderError(e?.name === "AbortError" || signal?.aborted ? "timeout" : "unknown");
  }
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
    const data = await postJson(`${base}/chat/completions`, { Authorization: `Bearer ${api_key}` }, body, signal);
    const text = data?.choices?.[0]?.message?.content;
    return typeof text === "string" ? text : "";
  }

  throw new ProviderError("model");
}
