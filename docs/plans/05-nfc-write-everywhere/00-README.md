# 05 — Writing NFC cards from any device

Master plan: none (`SPEC.md` gets a short update in slice 01) · Builds on: `web/src/admin/NfcWriter.jsx`, `web/src/admin/BranchQr.jsx`

## Goal
- Staff on Android, iPhone and a desktop browser can all get a branch's NFC card written, and the app tells each of them the exact route for their device instead of a generic "not supported" note.
- Nothing about **reading** changes: a written card opens `/f/{slug}` on any phone.

## The platform limit (read this first)
Browsers can write NFC only through Web NFC, which exists only in **Chrome on Android over HTTPS**. Safari/iPhone (all iOS browsers), Firefox and every desktop browser cannot write a tag, and no website code can change that. Therefore:
- **This plan (web only):** make Android Chrome writing easy to reach from any device, and give iPhone and desktop staff a guided route using a free NFC writing app or a USB reader.
- **Not achievable in a browser:** writing directly from iPhone or desktop browsers. That needs a native app (iOS Core NFC, Android) or a USB reader helper, which is a separate, larger project (see N9). It is **not** part of this plan.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| N1 | **Device detection.** A pure helper `web/src/lib/nfcSupport.js` exports `nfcEnvironment()` returning one of: `android-web-nfc` (`'NDEFReader' in window` and `isSecureContext`), `android-other` (Android user agent but no Web NFC, e.g. non-Chrome browser or plain HTTP), `ios` (iPhone/iPad, including iPadOS reporting as Mac with touch), `desktop` (everything else). `NfcWriter` uses it instead of its inline check. |
| N2 | **Android Chrome (unchanged).** `android-web-nfc` keeps today's Write button, errors and local-address warning exactly as they are. |
| N3 | **Hand off to an Android phone.** On `desktop`, `ios` and `android-other`, the dialog shows a second QR (canvas, 160 px) captioned "Scan with an Android phone to write this card". It encodes `${origin}/admin/companies/{companyId}?nfc={branchId}`. Opening it on a phone shows the company page with that branch's NFC & QR dialog already open (the page reads `?nfc=` once, opens the matching branch, then removes the parameter from the URL). Unknown or archived branch id = no dialog, no error. This link needs a signed-in Super Admin session; it carries no secret. |
| N4 | **Login return path.** `RequireRole` redirects signed-out users to `/login` with `state={{ from: location }}` (pathname + search); `LoginPage` navigates to `from` after sign-in when it is an `/admin` or `/business` path the role may open, otherwise to the role's home as today. No open redirect: only same-origin paths starting with `/admin` or `/business` are honoured. |
| N5 | **Guided fallback panel.** A collapsible "Other ways to write this card" (closed by default except on `ios` and `desktop`, where it is open) with steps by environment:<br>`ios`: 1 Tap "Send link to my phone"/Copy link. 2 Install the free "NFC Tools" app (App Store). 3 Write → Add a record → URL/URI → paste the link → Write → hold the card to the top edge of the iPhone. Note: needs iPhone 7 or newer.<br>`android-other`: open this page in Chrome (button "Copy page address"), or use NFC Tools.<br>`desktop`: use the Android hand-off QR, or write with a USB NFC reader (for example ACR122U-class) and the free NFC Tools desktop app, pasting the link as a URL record.<br>Plain text only, no external links, no brand logos. |
| N6 | **Send link to my phone.** A "Send link" button: uses `navigator.share({ title, url })` when available; otherwise opens `mailto:?subject=<branch name> feedback link&body=<url>`. It sends the **feedback URL** (the thing to write), not the admin link. Errors from a dismissed share sheet (`AbortError`) are ignored. |
| N7 | **Reassurance line.** Under the QR in `BranchQr`: "Any phone can read the card. Only writing needs the steps below." |
| N8 | **Access.** Unchanged: the NFC & QR dialog stays Super Admin only. No database, RLS or API changes in this plan. |
| N9 | **Out of scope (later, needs its own plan and approval).** A native iOS/Android app that writes tags (Apple developer account, NFC entitlement, TestFlight/Play distribution); a desktop helper or WebUSB/WebHID writer for USB readers (unreliable across browsers and OS drivers); bulk CSV export for card vendors; Business Admin access to NFC & QR. |

## Status
- [x] 01 — Device detection, Android hand-off QR, guided fallback, login return path, SPEC and acceptance evidence (device checks NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | none | Sonnet | `web/src/lib/nfcSupport.js` (new), `web/src/admin/NfcWriter.jsx`, `web/src/admin/BranchQr.jsx`, `web/src/admin/CompanyDetailPage.jsx`, `web/src/auth/RequireRole.jsx`, `web/src/auth/LoginPage.jsx`, `web/src/styles.css` (appended `nfc-` block), `SPEC.md`, `docs/plans/05-nfc-write-everywhere/RESULT.md` |

One slice, no schema change, so nothing to run in parallel.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; `cd web && npm run build` must pass; no new dependencies (the `qrcode` package is already installed); append `## Result` to the slice file.

## Acceptance checklist
- [ ] Android Chrome over HTTPS: the dialog still shows the Write button and writing a card works as before.
- [ ] Desktop browser: the dialog shows the hand-off QR and the desktop steps; scanning it with an Android phone opens the company page (after login if needed) with that branch's NFC & QR dialog already open.
- [ ] iPhone Safari: the dialog shows the NFC Tools steps and "Send link"; the shared/copied link is the feedback URL.
- [ ] Android without Web NFC (e.g. Firefox, or plain HTTP): the dialog says to open the page in Chrome and offers the copy action.
- [ ] Signed-out user following an `/admin/...?nfc=...` link signs in and lands on that page; a crafted `from` to another origin or path is ignored.
- [ ] `?nfc=` with an unknown branch id opens nothing and shows no error; the parameter is removed from the URL after use.
- [x] `SPEC.md` states the browser limit and the supported routes per device.
