# TapReview

NFC / QR customer feedback for multi-branch businesses. Spec: [SPEC.md](SPEC.md).
Stack: React + Vite (plain JavaScript), Supabase (Postgres + RLS + Auth + one Edge Function).

## Setup

1. **Database:** apply every file in `supabase/migrations/` **in order** (`..._init.sql`, `..._last_seen.sql`, `..._list_business_admins.sql`, `..._dashboard_stats.sql`) to your Supabase project (SQL editor or `supabase db push`).
2. **Edge Function:** `supabase functions deploy create-business-admin` (uses the project's built-in service-role key; never put it in the frontend).
3. **First Super Admin:** create a user in Supabase Auth, then run:
   ```sql
   insert into public.profiles (user_id, role) select id, 'super_admin' from auth.users where email = 'you@example.com';
   ```
4. **Frontend:** `cd web && cp .env.example .env.local`, fill in the project URL and anon key, then `npm install && npm run dev`.
   Production: `npm run build` and serve `web/dist` with an SPA fallback (every path serves `index.html`).

## Deploy (GitHub + Vercel)

1. Push this repo to GitHub (`web/.env` is git-ignored; only `web/.env.example` is committed).
2. In Vercel, import the repo and set **Root Directory** to `web`. The Vite preset is detected; [web/vercel.json](web/vercel.json) provides the SPA fallback so `/admin/...` and customer links `/f/{slug}` work on refresh.
3. Add environment variables (Production + Preview): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`.
4. In Supabase → Authentication → URL Configuration, add the Vercel domain as the Site URL and a redirect URL.
5. The database migrations and the Edge Function are deployed with the Supabase CLI, not Vercel.

Everything else (categories, questions, companies, branches, Business Admin logins) is done in the app as Super Admin.

## Tests

`supabase/tests/` holds RLS/RPC assertions for plain Postgres:

```bash
docker run -d --name fb_pg -e POSTGRES_PASSWORD=t postgres:16-alpine
cat supabase/tests/00_stubs.sql supabase/migrations/*.sql supabase/tests/rls.sql | docker exec -i fb_pg psql -U postgres -v ON_ERROR_STOP=1 -q
```
Ends with `ALL RLS TESTS PASSED`.

## Notes

- Customers use `/f/{slug}`; the NFC tag stores that URL and the QR code is generated per branch.
- Every customer sees the Google review link (no review gating).
- No email/SMS alerts in v1. Instead: a "new" badge on the Feedback menu item, the browser tab title count, and an in-page "N new responses" prompt, refreshed every 20 s while the tab is open.
