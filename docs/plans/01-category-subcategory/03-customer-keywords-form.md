# 01/03 — Customer keyword form, review text, feedback display

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 01/01 · Parallel with: 01/02 (disjoint files)

## Decisions you need
C6 (form RPC payload), C7 (submit RPC signature/errors), C8 (review text), C11 (display), C13 (stack) — run `grep -E '^\| (C6|C7|C8|C11|C13) ' 00-README.md`.

## Read first
- `web/src/customer/FeedbackPage.jsx` (loads form via RPC, submits), `FeedbackFormView.jsx`, `QuestionField.jsx` (to delete), `ThankYou.jsx`, `StarRating.jsx`.
- `web/src/lib/types.js` (`QUESTION_TYPE_LABEL`, `SOFT_QUESTION_LIMIT`, `EMPTY_DRAFT`).
- `web/src/shared/SubmissionCard.jsx` (renders `s.answers`) and `FeedbackListPage.jsx` (the `.select('id,branch_id,...answers...')` call).

## Scope (files you own)
`web/src/customer/**`, `web/src/shared/**`, `web/src/lib/types.js`, and new rules appended to `web/src/styles.css` only for keyword chips (class names prefixed `kw-`; slice 02 appends `tax-` rules, keep blocks separate).

## Tasks
1. **Draft/types.** `EMPTY_DRAFT = { rating: 0, keywordIds: [], comment: '', contact: '' }`; remove the question constants.
2. **Review text (C8).** Add `web/src/customer/reviewText.js` exporting `composeReview({ company, rating, labels })` exactly per C8. In Result, show its output for 0/1/2/3 labels at ratings 5 and 2 (run with `node`).
3. **Form view.** Replace question rendering with a chip group (toggle buttons, `aria-pressed`, min 44px tap target) of `form.keywords`, max 8 selectable (disable the rest, hint "Up to 8"). Hide the group if the list is empty. The comment textarea is prefilled by `composeReview` and re-composed on rating/keyword change until the user types in it (track `edited` in local state; manual edits are never overwritten). Delete `QuestionField.jsx`.
4. **Submit.** Call `submit_feedback` with `{ p_slug, p_rating, p_keyword_ids, p_comment, p_contact }`. Map `22023` to "Please check your selection and try again"; keep existing handling for `P0002` (not found) and `54000` (too many). ThankYou keeps the Google button, copy-comment button and low-rating manager card unchanged and equal in prominence.
5. **Display (C11).** `FeedbackListPage` selects `keywords` instead of `answers`; `SubmissionCard` renders `s.keywords` labels as chips and nothing when empty. Remove the answers markup and its CSS only if nothing else uses it.

## Done when
- `cd web && npm run build` passes.
- Manually on a mobile viewport against a seeded local DB: chips show for the branch's subcategory, review text updates, a manual edit sticks, submit succeeds, chips appear on the feedback list for Super Admin and Business Admin.
- `grep -rn -i "question\|answers" web/src/customer web/src/shared web/src/lib` returns nothing relevant.
- Append `## Result`.

## Result
Changed: `web/src/customer/FeedbackFormView.jsx` (chip group, max 8, `edited` tracking, composeReview prefill), `FeedbackPage.jsx` (p_keyword_ids, 22023 message), new `customer/reviewText.js`, deleted `customer/QuestionField.jsx`, `lib/types.js` (EMPTY_DRAFT with keywordIds, `MAX_KEYWORDS = 8`; removed question constants and `isAnswered`), `shared/FeedbackListPage.jsx` (selects `keywords`), `shared/SubmissionCard.jsx` (keyword pills in `.kw-list`), `styles.css` (removed `.answers`, appended `kw-` block). ThankYou unchanged.
Checks: `cd web && npm run build` PASS; `grep -rniE "question|answers" web/src/customer web/src/shared web/src/lib` empty. Manual mobile/DB checks NOT RUN (no database).
composeReview (company Acme), ratings 5 / 2:
- [] : "Great experience at Acme!" / "My visit to Acme could have been better."
- [Service] : "...I especially liked the service." / "...better, mainly the service."
- [Service, Wi-Fi] : "...liked the service and Wi-Fi." / "...mainly the service and Wi-Fi."
- [Service, WiFi, Parking lot] : "...liked the service, WiFi and parking lot." / "...mainly the service, WiFi and parking lot."
Notes: FeedbackFormView reads `form.keywords` (admin FormPreview must pass `keywords`, `company_name`). Existing code had no specific P0002/54000 messages (generic error); kept as-is.
