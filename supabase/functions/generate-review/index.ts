// Drafts a customer review with the configured AI provider (plan 06, A5).
// Called by the public feedback page with the anon key. The service-role client is used
// only for the runtime RPCs; the key and the prompt are never logged or returned.
import { createClient } from "npm:@supabase/supabase-js@2";
import { generateWithRetry } from "../_shared/providers.js";
import { buildPrompt, sanitizeReview } from "../_shared/prompt.js";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_BODY = 4096;
const TIMEOUT_MS = 8000;

// Best-effort failure log (plan 09, H4). Never throws, never changes the response, 1 s cap.
// Only step, provider, model, error kind, HTTP status and the already-redacted detail are passed.
async function logError(admin, f) {
  let timer;
  try {
    await Promise.race([
      admin.rpc("log_ai_error", {
        p_stage: f.stage,
        p_provider: f.provider ?? null,
        p_model: f.model ?? null,
        p_kind: f.kind ?? null,
        p_status: f.status ?? null,
        p_detail: f.detail ?? null,
      }),
      new Promise((resolve) => { timer = setTimeout(resolve, 1000); }),
    ]);
  } catch { /* logging must never affect the customer */ } finally {
    clearTimeout(timer);
  }
}

// Best-effort switch-off when the provider rejects the key or model (plan 10, T8). Never throws, 1 s cap.
async function recordFailedTest(admin, provider) {
  let timer;
  try {
    await Promise.race([
      admin.rpc("record_ai_test", { p_provider: provider, p_ok: false }),
      new Promise((resolve) => { timer = setTimeout(resolve, 1000); }),
    ]);
  } catch { /* must never affect the customer */ } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // 1. Validate the body before doing anything.
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY) return json({ error: "too_large" }, 413);
  let raw;
  try { raw = await req.text(); } catch { return json({ error: "invalid_input" }, 400); }
  if (new TextEncoder().encode(raw).length > MAX_BODY) return json({ error: "too_large" }, 413);
  let body;
  try { body = JSON.parse(raw); } catch { return json({ error: "invalid_input" }, 400); }
  if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "invalid_input" }, 400);
  const { slug, rating, keyword_ids } = body;
  if (typeof slug !== "string" || slug.length < 1 || slug.length > 64) return json({ error: "invalid_input" }, 400);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return json({ error: "invalid_input" }, 400);
  if (!Array.isArray(keyword_ids) || keyword_ids.length > 10 ||
      !keyword_ids.every((id) => typeof id === "string" && UUID.test(id))) {
    return json({ error: "invalid_input" }, 400);
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));

  // 2. Business context and keyword labels (server-side validation of the ids).
  const { data: ctx, error: ctxErr } = await admin.rpc("get_review_context", {
    p_slug: slug, p_keyword_ids: keyword_ids,
  });
  if (ctxErr) {
    if (ctxErr.code === "22023") return json({ error: "invalid_keywords" }, 400);
    console.error("generate-review: context_failed");
    await logError(admin, { stage: "context", kind: ctxErr.code ?? null });
    return json({ error: "server_error" }, 500);
  }
  if (!ctx) return json({ error: "not_found" }, 404);

  // 3. Active provider and key.
  const { data: runtime, error: rtErr } = await admin.rpc("get_ai_runtime");
  if (rtErr) {
    console.error("generate-review: runtime_failed");
    await logError(admin, { stage: "runtime", kind: rtErr.code ?? null });
    return json({ error: "server_error" }, 500);
  }
  if (!runtime) {
    await logError(admin, { stage: "not_configured" });
    return json({ error: "ai_unavailable" }, 503);
  }

  // 4. Provider call with an 8 s timeout, then sanitize.
  const { system, user } = buildPrompt({ ...ctx, rating });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const text = await generateWithRetry({
      provider: runtime.provider,
      model: runtime.model,
      base_url: runtime.base_url,
      api_key: runtime.api_key,
      system,
      user,
      signal: controller.signal,
    });
    const review = sanitizeReview(text);
    if (!review) {
      console.warn("generate-review: ai_failed empty");
      await logError(admin, { stage: "empty", provider: runtime.provider, model: runtime.model });
      return json({ error: "ai_failed" }, 502);
    }
    return json({ review });
  } catch (e) {
    console.warn(`generate-review: ai_failed ${e?.kind ?? "unknown"}`);
    await logError(admin, {
      stage: "provider",
      provider: runtime.provider,
      model: runtime.model,
      kind: e?.kind ?? "unknown",
      status: e?.status ?? null,
      detail: e?.detail ?? null,
    });
    if (e?.kind === "auth" || e?.kind === "model") await recordFailedTest(admin, runtime.provider);
    return json({ error: "ai_failed" }, 502);
  } finally {
    clearTimeout(timer);
  }
});
