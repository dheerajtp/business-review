# 06/04 — Customer "Write my review with AI" button

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 06/01 · Parallel with: 06/02, 06/03 (disjoint files)

## Decisions you need
A4 (`ai_enabled` in the form payload), A5 (request/response/status codes), A10 (UI behaviour and texts), A14 (wording) — run `grep -E '^\| (A4|A5|A10|A14) ' 00-README.md`.

## Read first
- `web/src/customer/FeedbackFormView.jsx`: the `edited` state, the `composeReview` re-compose on keyword/rating change, the chip group, the comment textarea (~line 60).
- `web/src/customer/FeedbackPage.jsx`: how the form RPC result (`form`) and `slug` are held and passed down.
- `web/src/customer/reviewText.js` (template draft stays unchanged) and `ThankYou.jsx` (unchanged).
- `web/src/lib/db.js` (`supabase`), `web/src/lib/types.js` (`EMPTY_DRAFT`, `MAX_KEYWORDS`).

## Scope (files you own)
`web/src/customer/**`, `web/src/lib/types.js`, and an appended `aib-` block in `web/src/styles.css` only if the button/notice needs it.

## Tasks
1. **Button (A10).** Show "Write my review with AI" under the keyword chips only when `form.ai_enabled === true` and `draft.keywordIds.length >= 1` and a rating is chosen. Pass `slug` to `FeedbackFormView` if it is not already available there.
2. **Call.** On click: `supabase.functions.invoke('generate-review', { body: { slug, rating: draft.rating, keyword_ids: draft.keywordIds } })` with a 10 s client timeout (`Promise.race` with a timer; clear it). While loading: button disabled, `aria-busy="true"`, label "Writing…". Success (`data?.review` string): set `comment` to it (respect `maxLength` 2000), `setEdited(true)`, switch the button label to "Regenerate", show the note "Suggested by AI. Edit it so it matches your visit." Failure: keep the current text and show "Couldn't generate right now. You can edit the text below."; if the error response status is 429 (look at `error.context?.status`) show "Please try again in a few minutes." instead. Never show provider details or the raw error.
3. **Template unchanged.** The existing template draft and its re-compose rules stay as they are; AI text stops being overwritten once `edited` is true. Changing the rating or keywords after an AI draft does not auto-regenerate (the customer taps Regenerate).
4. **Hidden when off.** If `ai_enabled` is false or missing, nothing changes on the page.
5. **Submit.** Unchanged: the submitted comment is whatever is in the textarea.

## Done when
- `cd web && npm run build` passes; `grep -rniE "question|answers" web/src/customer web/src/lib` is empty.
- With `ai_enabled` false the form renders exactly as before (state how you verified by reading the code).
- Manual mobile checks (button, regenerate, failure message, 429 message) need the deployed function and a key: report NOT RUN.
- Append `## Result`.

## Result
- Changed `web/src/customer/FeedbackFormView.jsx` (new `slug` prop, `generate()` with 10 s Promise.race timeout, button/notes under chips) and `web/src/customer/FeedbackPage.jsx` (passes `slug`). No styles added (reuses `btn`, `muted small`).
- `npm run build` PASS; grep question|answers in web/src/customer web/src/lib empty.
- ai_enabled false/missing: the new block is guarded by `form.ai_enabled === true`, so nothing renders; ai state is inert. Admin preview passes no slug/ai_enabled, so unchanged.
- Manual mobile checks (button, regenerate, failure, 429): NOT RUN.
