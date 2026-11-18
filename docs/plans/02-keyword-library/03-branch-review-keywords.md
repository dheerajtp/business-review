# 02/03 — Branch review page: keyword selection in place of questions

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 02/01 · Parallel with: 02/02 (disjoint files)

## Decisions you need
K6 (form RPC payload), K7 (submit rules/errors), K8 (page layout and review text) — run `grep -E '^\| (K6|K7|K8) ' 00-README.md`.

## Read first
- `web/src/customer/FeedbackFormView.jsx` (chip group, `edited` tracking, composeReview prefill), `FeedbackPage.jsx` (load + submit, error mapping), `reviewText.js`, `ThankYou.jsx`.
- `web/src/lib/types.js` (`MAX_KEYWORDS`, `EMPTY_DRAFT`).

## Scope (files you own)
`web/src/customer/**`, `web/src/lib/types.js`, and an appended `kwc-` block in `web/src/styles.css` only if chip layout needs it (plan 01's `kw-` rules may be reused as is).

## Tasks
1. **Constants.** `MAX_KEYWORDS = 10`; hint text "Up to 10".
2. **Layout (K8).** Order on `/f/{slug}`: stars → keyword chips (heading like "What stood out?") → editable review text → contact (shown only when rating < 4, unchanged). Chips render for every rating; hide the whole chip block when `form.keywords` is empty. Selection persists when rating changes. Chips keep `aria-pressed`, ≥ 44px tap target, picked order from the RPC.
3. **reviewText.js (K8).** Implement the four message forms and join rule exactly as K8 (labels as stored, no lower-casing; remove the old lower-casing logic). Show outputs for 0/1/2/3 labels at ratings 5 and 2 in Result (run with `node`).
4. **Submit (K7).** `p_keyword_ids` as today; map `22023` to "Please check your selection and try again". Google button, copy button and low-rating manager card unchanged and equal in prominence.

## Done when
- `cd web && npm run build` passes; `grep -rniE "question|answers" web/src/customer web/src/lib` is empty.
- Manual mobile checks need a database: report NOT RUN if unavailable.
- Append `## Result`.

## Result
- Changed: `web/src/customer/reviewText.js` (K8 forms, labels as stored, join rule, lower-casing removed), `web/src/lib/types.js` (`MAX_KEYWORDS = 10`).
- Already compliant, unchanged: FeedbackFormView (stars, chips, review text, contact <4; chips hidden when empty; selection persists; aria-pressed; hint uses MAX_KEYWORDS) and FeedbackPage (22023 -> "Please check your selection and try again"). Chips appear once a star is tapped (same reveal as before).
- composeReview outputs (company Acme, labels Food/Service/Clean Rooms): rating 5: `Great experience at Acme!` / `... Recommended for Food.` / `... for Food and Service.` / `... for Food, Service and Clean Rooms.`; rating 2: `My visit to Acme could have been better.` / `..., especially regarding Food.` / `... Food and Service.` / `... Food, Service and Clean Rooms.`
- `npm run build` PASS; grep question|answers in customer/lib empty. Manual mobile checks NOT RUN (no database).
