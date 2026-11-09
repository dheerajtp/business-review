// Creates a Business Admin login for a company. Super Admin only.
// Needs the service-role key, so it cannot run in the browser.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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
  const { email, password, company_id } = body;
  if (typeof email !== "string" || !EMAIL.test(email) || email.length > 200) return json({ error: "Valid email required" }, 400);
  if (typeof password !== "string" || password.length < 8 || password.length > 72) return json({ error: "Password must be 8-72 characters" }, 400);
  if (typeof company_id !== "string" || !UUID.test(company_id)) return json({ error: "Valid company required" }, 400);

  const { data: company } = await admin.from("companies").select("id").eq("id", company_id).maybeSingle();
  if (!company) return json({ error: "Company not found" }, 404);

  // 3. Create the auth user, then the profile; undo the user if the profile fails.
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
  });
  if (createErr || !created.user) return json({ error: createErr?.message ?? "Could not create user" }, 400);

  const { error: profileErr } = await admin.from("profiles").insert({
    user_id: created.user.id, role: "business_admin", company_id,
  });
  if (profileErr) {
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: "Could not create profile" }, 500);
  }
  return json({ user_id: created.user.id, email });
});
