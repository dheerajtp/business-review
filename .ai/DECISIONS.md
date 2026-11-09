# Architecture & Engineering Decisions

Record important, durable decisions that should remain known across future AI sessions.

Use this format:

## YYYY-MM-DD — Decision title

### Decision
What was decided.

### Reason
Why it was decided.

### Impact
What future implementation must respect.

---

## 2026-10-05 — No review gating

### Decision
Every customer sees the Google review link; ratings below 4 are additionally shown to the company as needing attention.

### Reason
Google prohibits review gating; the client's listings would be at risk.

### Impact
Never hide or demote the Google link by rating.

---

## 2026-10-05 — Tenancy and questions

### Decision
Tenant = company (one category each) with many branches. Questions belong to a category; a company may have extra questions (`questions.company_id`) added on top, created only by the Super Admin after a request. No AI and no email/SMS alerts in v1.

### Impact
Customers use RPCs only (no table access for `anon`). Business Admins never write questions or branches.

---

## 2026-11-09 — Hosting layout

### Decision
Keep the `web/` + `supabase/` layout. Deploy `web/` to Vercel with Root Directory `web`; a single root `.gitignore` covers the repo.

### Reason
The layout already works with Vercel; hoisting `web/` would be a large diff with no benefit.

### Impact
Direct hits on any path must serve `index.html` (customer NFC/QR links `/f/{slug}`). Never commit `.env*` other than `.env.example`.
