# 14/01 Result: billing refusals reclassified as quota

## Changed files
- `supabase/functions/_shared/providers.js`: in `request()` the `!res.ok` branch now throws kind `quota` when status is 402, or when status is 400/403 and the redacted detail matches the billing pattern. All other statuses keep `statusKind`. `status` and redacted `detail` are unchanged.
- `web/src/admin/AiSettingsPage.jsx`: `TEST_REASONS.quota` replaced with the approved text (only that line touched).

## Checks
- `cd web && npm run build` → PASS (`✓ built in 325ms`)
- Node mock check (`generate()` with `fetch` mocked; copies in the scratchpad `billing-mock/`, not the repo):
  - 400 "credit balance is too low" → quota, status 400: PASS
  - 400 "model not found" → model, status 400: PASS
  - 402 empty body → quota, status 402: PASS
  - 429 → quota: PASS
  - 500 → unavailable: PASS
  - 400 body echoing the key → model; key absent from message and detail: PASS
  - 403 billing text → quota; 403 plain "forbidden" → auth (unchanged): PASS
  - Result: ALL PASS
- Deploy of the edge function: NOT RUN
- Browser check of the Test message: NOT RUN
