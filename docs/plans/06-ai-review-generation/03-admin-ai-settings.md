# 06/03 — Admin AI settings page

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 06/01 · Parallel with: 06/02, 06/04 (disjoint files)

## Decisions you need
A2 (RPC names, args, errors, what get_ai_settings returns), A8 (test-ai request and reply), A9 (page), A11 (key handling) — run `grep -E '^\| (A2|A8|A9|A11) ' 00-README.md`.

## Read first
- `web/src/admin/KeywordsPage.jsx` and `web/src/admin/CompaniesPage.jsx`: page layout (`PageHead`), `useAsync`, `must`/`supabase` from `web/src/lib/db.js`, modal/confirm usage (`web/src/ui/ConfirmDialog.jsx`, `Field.jsx`, `ErrorState.jsx`).
- `web/src/admin/AdminLoginForm.jsx` lines near `supabase.functions.invoke('create-business-admin'`: how an Edge Function is invoked and its error handled.
- `web/src/App.jsx` (Super Admin lazy routes) and `web/src/layout/Sidebar.jsx` + `NavIcon.jsx` (nav array and icon map; the `keywords` entry is a pattern).
- `web/src/auth/PasswordField.jsx`: reuse for the key input if suitable.

## Scope (files you own)
`web/src/admin/AiSettingsPage.jsx` (new), `web/src/App.jsx`, `web/src/layout/Sidebar.jsx`, `web/src/layout/NavIcon.jsx`, appended `ai-` block in `web/src/styles.css`.

## Tasks
1. **Route and nav (A9).** Lazy route `/admin/ai` inside the Super Admin group; sidebar item "AI review" under Set up; add an `ai` icon (simple sparkle/chip path) to `NavIcon`.
2. **Load.** `must(supabase.rpc('get_ai_settings'))` → `{active_provider, is_enabled, daily_limit, providers}`. Provider list is fixed: `gemini` "Gemini", `anthropic` "Claude (Anthropic)", `openai` "OpenAI (GPT)", `custom` "Custom (OpenAI-compatible)". Show one card per provider with the fields from A9; model placeholders `gemini-2.5-flash`, `claude-haiku-5-5`, `gpt-4o-mini`, custom `model name`. Base URL field only for `custom` (required) and `openai` (optional, placeholder `https://api.openai.com/v1`).
3. **Per-provider actions.** Save → `supabase.rpc('set_ai_provider', { p_provider, p_model, p_base_url: value || null, p_api_key: key || null })`; clear the key field in state afterwards and reload. Key input is `type="password"`, `autoComplete="off"`, `maxLength={400}`; when `has_key`, show "Saved, ending {key_hint}" and the placeholder "Leave empty to keep the saved key". Test → `supabase.functions.invoke('test-ai', { body: { provider } })`; show the sample text on `ok`, else a message by `reason`: `no_key` "Save a key first.", `auth` "The provider rejected the key.", `model` "The model name or base URL looks wrong.", `network` "Couldn't reach the provider.", `timeout` "The provider took too long.", else "Test failed." Remove key → ConfirmDialog then `clear_ai_provider_key`.
4. **Global section.** Active provider select (only providers with `has_key`), "Enable AI reviews" checkbox, daily limit number input (1–100000), Save → `set_ai_settings`. Disable the enable toggle with a hint when the chosen provider has no key.
5. **Errors.** Map RPC errors: message `forbidden` → "Only a Super Admin can change this."; `provider has no key` → "Save a key for this provider first."; `invalid base url` → "Use a public https address (no localhost, IP addresses or internal hosts)."; otherwise `errorMessage(err)`.
6. **Never** log, store (no localStorage/sessionStorage) or display the key after saving.

## Done when
- `cd web && npm run build` passes; `grep -rn "console\.\|localStorage\|sessionStorage" web/src/admin/AiSettingsPage.jsx` is empty.
- Manual checks (save, test, remove, enable, Business Admin cannot open the route) need a database and the deployed functions: report NOT RUN if unavailable.
- Append `## Result`.

## Result
Changed: `web/src/admin/AiSettingsPage.jsx` (new), `web/src/App.jsx` (lazy route `/admin/ai`), `web/src/layout/Sidebar.jsx` (Set up > "AI review"), `web/src/layout/NavIcon.jsx` (`ai` icon), `web/src/styles.css` (appended `ai-` block).
- `cd web && npm run build` → PASS; grep for console/localStorage/sessionStorage in the page → empty (PASS).
- Manual checks (save, test, remove, enable, Business Admin blocked) → NOT RUN (no database/functions).
- Notes: provider cards remount when `updated_at`/`has_key` change, so the "Saved." message is replaced by the refreshed card. Test button is disabled until a key is saved. `test-ai` call treats any invoke error as "Test failed."
