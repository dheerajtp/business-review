// Sends a fixed sample through one AI provider to check its key and model (plan 06, A8).
// Super Admin only. Never echoes the key; the provider's error text is returned redacted and truncated (plan 08, G1).
import { createClient } from "npm:@supabase/supabase-js@2";
import { generate, listModels } from "../_shared/providers.js";
import { buildPrompt, sanitizeReview } from "../_shared/prompt.js";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const PROVIDERS = ["gemini", "anthropic", "openai", "custom"];
const TIMEOUT_MS = 8000;
const SAMPLE = {
  company_name: "Sample Cafe",
  branch_name: "Main",
  category_name: "Food & Drink",
  subcategory_name: "Cafe",
  rating: 5,
  labels: ["friendly staff", "great coffee"],
};

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

  // 3. Load the provider's model, base URL and key.
  const { data: runtime, error: rtErr } = await admin.rpc("get_ai_provider_runtime", { p_provider: provider });
  if (rtErr) {
    console.error("test-ai: runtime_failed");
    return json({ error: "Could not load provider" }, 500);
  }
  if (!runtime) return json({ ok: false, reason: "no_key" });

  const fail = (e) => {
    const reason = ["auth", "model", "quota", "unavailable", "network", "timeout", "unknown"].includes(e?.kind) ? e.kind : "unknown";
    const out: Record<string, unknown> = { ok: false, reason };
    if (typeof e?.status === "number") out.status = e.status;
    if (typeof e?.detail === "string" && e.detail !== "") out.detail = e.detail;
    return json(out);
  };

  // 4. Send the sample through the same adapter with an 8 s timeout.
  const { system, user } = buildPrompt(SAMPLE);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    if (action === "list_models") {
      const models = await listModels({
        provider: runtime.provider,
        base_url: runtime.base_url,
        api_key: runtime.api_key,
        signal: controller.signal,
      });
      return json({ ok: true, models });
    }
    const text = await generate({
      provider: runtime.provider,
      model: runtime.model,
      base_url: runtime.base_url,
      api_key: runtime.api_key,
      system,
      user,
      signal: controller.signal,
    });
    const sample = sanitizeReview(text);
    if (!sample) return json({ ok: false, reason: "empty" });
    return json({ ok: true, sample });
  } catch (e) {
    return fail(e);
  } finally {
    clearTimeout(timer);
  }
});
