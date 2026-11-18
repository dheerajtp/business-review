# 05 acceptance evidence

Verified here: build, greps, node run of `nfcEnvironment`/`handoffUrl`, code reading. No device or browser was available.

| Acceptance item | Status | Evidence / manual steps |
| --- | --- | --- |
| Android Chrome over HTTPS: Write button unchanged | Not verified (needs device) | Code: `android-web-nfc` branch of `NfcWriter` is the previous UI verbatim. Manual: on Android Chrome open the live site as Super Admin, open a branch's NFC & QR, tap Write to NFC card, hold a card, then tap it with a phone. |
| Desktop: hand-off QR and desktop steps; scan opens company page with dialog | Not verified (needs browser + Android phone) | Node: desktop UA returns `desktop`; `handoffUrl('c1','b1')` = `https://x.app/admin/companies/c1?nfc=b1`. Manual: desktop browser, open NFC & QR, check steps (open) and the 160 px QR; scan with an Android phone, sign in if asked, confirm that branch's dialog is open. |
| iPhone Safari: NFC Tools steps and Send link; link is the feedback URL | Not verified (needs iPhone) | Node: iPhone and iPadOS-as-Mac UAs return `ios`. Code: `send()` shares/mails `url` (the `/f/{slug}` link). Manual: on iPhone Safari open NFC & QR, check steps are open, tap Send link, confirm the shared URL ends with `/f/<slug>`. |
| Android without Web NFC: says to open in Chrome, offers copy | Not verified (needs device) | Node: Android Firefox UA and Android over non-secure context return `android-other`. Manual: Android Firefox (or the site over HTTP), open NFC & QR, tap Copy page address, paste in Chrome. |
| Signed-out `/admin/...?nfc=...` link signs in and lands there; crafted `from` ignored | Not verified in browser | Code: `RequireRole` passes `state.from = pathname + search`; `LoginPage.safeFrom` accepts only a string that is equal to or starts with `/admin/`, `/admin?`, `/business/`, `/business?` (business admins: `/business` only), and rejects `//...`, any backslash, schemes and other paths. Manual: signed out, open the link, sign in, confirm landing; set `state.from` to `//evil.com`, `https://evil.com`, `/other` and confirm role home. |
| `?nfc=` unknown id: nothing opens, no error, param removed | Not verified in browser | Code: effect in `CompanyDetailPage` opens only an active matching branch, always deletes `nfc` with `replace`. Manual: visit `/admin/companies/<id>?nfc=bogus`; confirm no dialog and URL cleaned. |
| `SPEC.md` states limit and routes per device | Verified | Added bullet after the "Company and branch CRUD" line in section 5. |
