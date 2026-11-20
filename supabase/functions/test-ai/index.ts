// Sends a fixed sample through one AI provider to check its key and model (plan 06, A8).
// Super Admin only. Never echoes the key; the provider's error text is returned redacted and truncated (plan 08, G1).
import { createClient } from "npm:@supabase/supabase-js@2";
import { generateResilient, listModels } from "../_shared/providers.js";
import { isValidBaseUrl, normalizeBaseUrl } from "../_shared/urlGuard.js";
import { buildPrompt, sanitizeReview } from "../_shared/prompt.js";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const PROVIDERS = ["gemini", "anthropic", "openai", "custom"];
const TIMEOUT_MS = 45000; // test action (retries + fallback); each attempt is capped at ATTEMPT_MS
const ATTEMPT_MS = 10000;
const LIST_TIMEOUT_MS = 8000;
const SAMPLE = {
  company_name: "Sample Cafe",
  branch_name: "Main",
  category_name: "Food & Drink",
  subcategory_name: "Cafe",
  rating: 5,
  labels: ["friendly staff", "great coffee"],
};

// Best-effort record of the test result (plan 10, T7). Never throws, never changes the response, 1 s cap.
async function recordTest(admin, provider, ok, busy) {
  let timer;
  try {
    await Promise.race([
      admin.rpc("record_ai_test", { p_provider: provider, p_ok: ok, p_busy: busy }),
      new Promise((resolve) => { timer = setTimeout(resolve, 1000); }),
    ]);
  } catch { /* recording must never affect the response */ } finally {
    clearTimeout(timer);
  }
}

// Stores the provider's model list (plan 12, L4). Never throws; true only when the call returned without error. 3 s cap.
async function syncModels(admin, provider, models) {
  let timer;
  try {
    const res = await Promise.race([
      admin.rpc("sync_ai_models", { p_provider: provider, p_models: models }),
      new Promise((resolve) => { timer = setTimeout(() => resolve(null), 3000); }),
    ]);
    return !!res && !res.error;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));

  // 1. Authenticate the caller and require super_admin.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /i, "");
  const { data: caller } = await admin.auth.getUser(token);
  if (!caller?.user) return json({ error: "Not signed in" }, 401);
  const { data: profile } = await admin.from("profiles").select("role").eq("user_id", caller.user.id).maybeSingle();
  if (profile?.role !== "super_admin") return json({ error: "Forbidden" }, 403);

  // 2. Validate the body before doing anything.
  let body;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  const provider = body?.provider;
  if (typeof provider !== "string" || !PROVIDERS.includes(provider)) return json({ error: "Valid provider required" }, 400);
  const action = body?.action ?? "test";
  if (action !== "test" && action !== "list_models") return json({ error: "Valid action required" }, 400);

  // Unsaved key (plan 13, S2): only list_models, used for this one call, never stored or logged.
  const typedKey = action === "list_models" && typeof body?.api_key === "string" && body.api_key !== "" ? body.api_key : null;
  if (typedKey !== null && (typedKey.length < 8 || typedKey.length > 400 || /\s/.test(typedKey))) {
    return json({ ok: false, reason: "auth" });
  }

  // 3. Load the provider's model, base URL and key.
  const { data: runtime, error: rtErr } = await admin.rpc("get_ai_provider_runtime", { p_provider: provider });
  if (rtErr) {
    console.error("test-ai: runtime_failed");
    return json({ error: "Could not load provider" }, 500);
  }
  if (!runtime && typedKey === null) return json({ ok: false, reason: "no_key" });

  const fail = (e) => {
    const reason = ["auth", "model", "quota", "unavailable", "network", "timeout", "unknown"].includes(e?.kind) ? e.kind : "unknown";
    const out: Record<string, unknown> = { ok: false, reason };
    if (typeof e?.status === "number") out.status = e.status;
    if (typeof e?.detail === "string" && e.detail !== "") out.detail = e.detail;
    return json(out);
  };

  // 4. Send the sample through the same adapter with a 22 s deadline (8 s for list_models).
  const { system, user } = buildPrompt(SAMPLE);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), action === "list_models" ? LIST_TIMEOUT_MS : TIMEOUT_MS);
  try {
    if (action === "list_models") {
      let baseUrl = runtime?.base_url;
      const typedUrl = typeof body?.base_url === "string" ? body.base_url.trim() : "";
      if (typedUrl !== "" && (provider === "custom" || provider === "openai")) {
        if (!isValidBaseUrl(typedUrl)) return json({ ok: false, reason: "unknown" });
        baseUrl = normalizeBaseUrl(typedUrl);
      }
      const models = await listModels({
        provider,
        base_url: baseUrl,
        api_key: typedKey ?? runtime.api_key,
        signal: controller.signal,
      });
      const stored = await syncModels(admin, provider, models);
      return json({ ok: true, models, stored });
    }
    const { text, model_used, used_fallback } = await generateResilient({
      provider: runtime.provider,
      model: runtime.model,
      base_url: runtime.base_url,
      api_key: runtime.api_key,
      system,
      user,
      fallback_model: runtime.fallback_model,
      attempts: 3,
      delaysMs: [1000, 2000],
      attemptTimeoutMs: ATTEMPT_MS,
      signal: controller.signal,
    });
    const sample = sanitizeReview(text);
    if (!sample) {
      await recordTest(admin, provider, false, false);
      return json({ ok: false, reason: "empty" });
    }
    await recordTest(admin, provider, true, false);
    return json({ ok: true, sample, model_used, used_fallback });
  } catch (e) {
    if (action === "test") {
      if (e?.kind === "unavailable") {
        // Provider busy: key and model were accepted.
        await recordTest(admin, provider, true, true);
        const out: Record<string, unknown> = { ok: true, busy: true };
        if (typeof e?.status === "number") out.status = e.status;
        if (typeof e?.detail === "string" && e.detail !== "") out.detail = e.detail;
        return json(out);
      }
      await recordTest(admin, provider, false, false);
    }
    return fail(e);
  } finally {
    clearTimeout(timer);
  }
});
