# 01/02 — Admin taxonomy UI, company form, remove question screens

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 01/01 · Parallel with: 01/03 (disjoint files; do not import `web/src/lib/types.js`)

## Decisions you need
C2 (tables/columns), C3 (who can write), C9 (admin UI), C10 (removals), C13 (stack) — run `grep -E '^\| (C2|C3|C9|C10|C13) ' 00-README.md`.

## Read first
- `web/src/admin/CategoriesPage.jsx`, `CategoryForm.jsx`: current CRUD pattern to extend (modal form, archive toggle, `useAsync`).
- `web/src/admin/CompanyForm.jsx`, `CompaniesPage.jsx`, `CompanyDetailPage.jsx`: where category is selected and shown.
- `web/src/lib/db.js` (`must`, `supabase`), `web/src/ui/{Modal,Field,EmptyState,ErrorState,ConfirmDialog}.jsx`.
- `web/src/App.jsx` routes, `web/src/layout/Sidebar.jsx` (nav array, `pendingRequests` badge), `NavIcon.jsx`, `NotificationMenu.jsx`, `web/src/notify/NewFeedbackProvider.jsx` + `NewFeedbackContext.js` (`pendingRequests`), `web/src/admin/GetStarted.jsx`.

## Scope (files you own)
`web/src/admin/**`, `web/src/layout/**`, `web/src/notify/**`, `web/src/business/**`, `web/src/App.jsx`, and `web/src/styles.css` only if new classes are required (append rules prefixed `tax-`; do not reorder). Slice 03 also appends `kw-` rules to `styles.css`; keep the two blocks separate to avoid merge conflicts.

## Tasks
1. **Taxonomy screen (C9).** Rework `CategoriesPage` into three sections (stack on mobile): categories → subcategories of the selected category → keywords of the selected subcategory. Selection kept in local state. Each level lists active first, archived dimmed with a Restore action. Add `SubcategoryForm.jsx` and `KeywordForm.jsx` modals (name/label with the C2 length limits via `maxLength`; category form keeps its description). New rows get `sort_order = max(existing)+1`. Archive/restore via `update({is_active})`; no delete. On a unique-index violation show "That name already exists here."
2. **Company form/list/detail (C9).** `CompanyForm`: Category select, then Subcategory select filtered to the category and active (plus the company's current); both required; saving writes `subcategory_id` only. Fetch categories and subcategories once in the parent and pass down. List and detail show `Category › Subcategory` (join through `subcategories(name, categories(name))`).
3. **Removals (C10).** Delete `QuestionsPage, QuestionForm, QuestionRow, RequestsPage, FormPreview` (admin) and `business/RequestQuestionPage`. Remove their routes/lazy imports, sidebar entries, the `questions` and `requests` icons if unused elsewhere, and `pendingRequests` from provider/context/sidebar/notification menu (including the `question_requests` query). Update the Get Started step to "Review categories and keywords" linking `/admin/categories`. Business Admin nav keeps only feedback/dashboard items.
4. **Dead code.** `grep -rn -i "question\|request" web/src/admin web/src/layout web/src/notify web/src/business web/src/App.jsx` must return nothing relevant afterwards.

## Done when
- `cd web && npm run build` passes (if it fails only because slice 03 files still import removed constants, say so in Result).
- Manually (dev server against a local seeded DB): create/rename/archive at all three levels; company create requires both selects; Business Admin login sees no question/request UI.
- Append `## Result`.

## Result
Changed: `web/src/admin/{CategoriesPage,CategoryForm,CompanyForm,CompaniesPage,CompanyDetailPage,GetStarted}.jsx`; added `SubcategoryForm.jsx`, `KeywordForm.jsx`, `saveError.js` (maps unique-violation text to "That name already exists here."; `must` drops the pg code, so it matches the message); `web/src/App.jsx`, `layout/{Sidebar,NavIcon,NotificationMenu}.jsx`, `notify/{NewFeedbackProvider.jsx,NewFeedbackContext.js}`; appended `tax-` block to `web/src/styles.css`. Deleted `admin/{QuestionsPage,QuestionForm,QuestionRow,RequestsPage,FormPreview}.jsx` and `business/RequestQuestionPage.jsx` (dir removed). Removed `questions`/`requests`/`add` icons, `pendingRequests` and the `question_requests` query. Get Started step is now key `keywords` (GetStarted is not rendered anywhere, so no counts caller to update).
Checks: `cd web && npm run build` PASS. `grep -rni "question\|request" web/src/admin web/src/layout web/src/notify web/src/App.jsx` returns nothing. Manual dev-server checks NOT RUN (no database).
Notes: `.notif-req` CSS rule is now unused (left in place). Company list/detail embed `subcategories(name,category_id,categories(name))`. `CategoryForm` takes a new `nextOrder` prop.
