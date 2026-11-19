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
    return json({ error: "server_error" }, 500);
  }
  if (!ctx) return json({ error: "not_found" }, 404);

  // 3. Active provider and key.
  const { data: runtime, error: rtErr } = await admin.rpc("get_ai_runtime");
  if (rtErr) {
    console.error("generate-review: runtime_failed");
    return json({ error: "server_error" }, 500);
  }
  if (!runtime) return json({ error: "ai_unavailable" }, 503);

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
      return json({ error: "ai_failed" }, 502);
    }
    return json({ review });
  } catch (e) {
    console.warn(`generate-review: ai_failed ${e?.kind ?? "unknown"}`);
    return json({ error: "ai_failed" }, 502);
  } finally {
    clearTimeout(timer);
  }
});
