# 05/01 — Device detection, Android hand-off QR, guided fallback, login return path, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: none

## Decisions you need
N1 (detection), N2 (Android unchanged), N3 (hand-off QR and `?nfc=`), N4 (login return path), N5 (guided steps), N6 (send link), N7 (reassurance), N8 (access) — run `grep -E '^\| (N1|N2|N3|N4|N5|N6|N7|N8) ' 00-README.md`.

## Read first
- `web/src/admin/NfcWriter.jsx`: the inline `canWrite`, `isLocalHost`, the `ERRORS` map and the write flow (keep the Android branch as is).
- `web/src/admin/BranchQr.jsx`: canvas QR via `qrcode`, `copy()`, the `qr` layout, where `<NfcWriter url={url} />` is rendered.
- `web/src/admin/CompanyDetailPage.jsx`: the `qr` state (`const [qr, setQr] = useState(null)`), how branches are loaded, `<BranchQr ... />` render at the bottom.
- `web/src/auth/RequireRole.jsx` (the `<Navigate to="/login" replace />` for `signed_out`) and `web/src/auth/LoginPage.jsx` (the `signed_in` `<Navigate ...>` line).
- `web/src/lib/format.js`: `feedbackUrl`.
- `SPEC.md`: the Branch/NFC lines in section 5.

## Scope (files you own)
`web/src/lib/nfcSupport.js` (new), `web/src/admin/NfcWriter.jsx`, `web/src/admin/BranchQr.jsx`, `web/src/admin/CompanyDetailPage.jsx`, `web/src/auth/RequireRole.jsx`, `web/src/auth/LoginPage.jsx`, an appended `nfc-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/05-nfc-write-everywhere/RESULT.md` (new).

## Tasks
1. **nfcSupport.js (N1).** Export `nfcEnvironment()` returning `'android-web-nfc' | 'android-other' | 'ios' | 'desktop'` exactly per N1 (guard `typeof window`/`navigator`; iPadOS check: `navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1`). Also export `isLocalHost()` moved from `NfcWriter` and `handoffUrl(companyId, branchId)` returning `${window.location.origin}/admin/companies/${companyId}?nfc=${branchId}`. Show in Result the returned value for sample user agents (Android Chrome, Android Firefox, iPhone Safari, desktop Chrome) by running the pure parts with `node` (inject fake `window`/`navigator`, so make the function accept an optional env object: `nfcEnvironment(env = globalThis)`).
2. **NfcWriter (N2, N5, N6).** Use `nfcEnvironment()`. `android-web-nfc`: the current UI unchanged. Other environments: replace the single paragraph with (a) the environment-specific steps from N5 (plain text, ordered list), (b) a "Send link" button per N6 (`navigator.share` else `mailto:`), (c) for `android-other` a "Copy page address" button copying `window.location.href`. Keep the section heading "Write to an NFC card". Wrap the steps in a `<details>` per N5 (open on `ios` and `desktop`). Props: add `branchName` and `handoff` (string URL or null).
3. **BranchQr (N3, N7).** Pass `branchName={branch.name}` and `handoff={handoffUrl(branch.company_id, branch.id)}` to `NfcWriter` when the environment is not `android-web-nfc`; render the second canvas QR (160 px, margin 1, caption "Scan with an Android phone to write this card") inside `NfcWriter` or `BranchQr` (your choice, but only draw it when `handoff` is set). Add the N7 sentence under the first QR. Check that the branch objects passed in already carry `company_id` and `id`; if not, take `companyId` from a new prop supplied by `CompanyDetailPage`.
4. **Deep link (N3).** In `CompanyDetailPage`, read `?nfc=<branchId>` with `useSearchParams` once branches have loaded; if it matches a branch in the list, call `setQr(branch)` and remove the `nfc` param (`setSearchParams(..., { replace: true })`); if not, only remove the param. Never show an error for an unknown id.
5. **Login return path (N4).** `RequireRole`: `<Navigate to="/login" replace state={{ from: location.pathname + location.search }} />` using `useLocation`. `LoginPage`: read `location.state?.from`; after sign-in navigate to it only when it is a string that starts with `/admin` or `/business` (not `//`, no scheme), and, for a `business_admin`, only when it starts with `/business`; otherwise the existing role home. Do not change the sign-in form behaviour.
6. **Styles.** Append a small `nfc-` block (steps list spacing, hand-off QR layout, `details` summary) to `styles.css`; no existing rule edits.
7. **SPEC.md.** In the branch/NFC lines of section 5 state: Web NFC works only in Chrome on Android over HTTPS; other devices use the hand-off QR, NFC Tools (iPhone) or a USB reader; reading works on any phone; native app is out of scope.
8. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs device/browser)" with exact manual steps per device. Only build, grep and node-run facts may be marked verified. Do not tick Status boxes.

## Done when
- `cd web && npm run build` passes.
- `grep -rn "NDEFReader" web/src` finds it only in `nfcSupport.js` and `NfcWriter.jsx` (write call).
- Open-redirect check by reading the code: a `from` of `//evil.com`, `https://evil.com` or `/other` is ignored (state this in Result with the exact condition).
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Files: web/src/lib/nfcSupport.js (new), web/src/admin/NfcWriter.jsx, BranchQr.jsx, CompanyDetailPage.jsx, web/src/auth/RequireRole.jsx, LoginPage.jsx, web/src/styles.css (appended nfc- block), SPEC.md, RESULT.md.
- `cd web && npm run build` PASS. `grep -rn NDEFReader web/src` only nfcSupport.js (detection) and NfcWriter.jsx (write call).
- Node run of `nfcEnvironment`: Android Chrome secure -> android-web-nfc; Android non-secure -> android-other; Android Firefox -> android-other; iPhone -> ios; iPadOS (MacIntel, touch) -> ios; desktop Chrome -> desktop.
- Open redirect: `LoginPage.safeFrom` ignores `from` unless it is a string, has no `//` prefix or backslash, and equals or starts with `/admin/`, `/admin?`, `/business/` or `/business?` (business admins only the `/business` forms). `//evil.com`, `https://evil.com`, `/other` all fall to the role home.
- Branch objects already carry `company_id` and `id`; no new prop needed. Hand-off QR drawn in NfcWriter. Unknown or archived branch id is silently ignored.
- Device-specific acceptance not verified; see RESULT.md.
