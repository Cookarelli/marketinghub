# Consignment verification — 17 September 2026

## Automated checks

All 16 tests pass, including:

- Five-stage generation and exact elapsed 48-hour reminders across both March and November Chicago DST changes; gaps/repeated local hours are rejected.
- Existing dated posts and Tuesday series retained, collision/three-post warnings, staff edits and additional spotlights retained.
- Atomic rollback, duplicate retries, interrupted-response recovery, stale snapshots, and preservation of subsequent staff edits.
- Complete record equality after PostgreSQL dump/restart, including campaign fields, production completion, owners, links and verification.
- Required approval evidence enforced through both record and campaign database functions; unsold lots cannot carry sale prices; changed facts cannot retain stale approval.
- Anonymous, unconfirmed, nonstaff, revoked and other-workspace access restrictions.

`pnpm run typecheck`, `pnpm run lint`, `pnpm test`, and `pnpm run build` passed. Lint retains the same three pre-existing advisory warnings: Hub image optimization and two full-page auth navigations.

## Browser checks

Used a temporary local Hub route connected to PGlite PostgreSQL via a localhost-only test adapter. It exercised the actual campaign schema and transaction functions with fictional staff, an `example.test` auction and two existing fictional calendar entries. The temporary route and adapter are not production changes.

- Opening March 5, 2026 at 10 a.m.; midweek March 7 at noon; reminder March 7 at 5 p.m.; closing March 9 at 6 p.m.; recap March 10 at noon, all Chicago time.
- Dropped a response after the database commit, then repeated the same payload twice. One campaign and five campaign posts remained, alongside both original entries.
- Full browser reload retained caption edits, owner, URLs, completed tasks and campaign metadata.
- Changing closing to 8 p.m. identified the reminder and closing posts; completed work and caption edits remained.
- Closing approval stayed disabled until production, deadline, lot-link and final-caption checks were complete. Approval and evidence persisted after reload.
- Recap approved only after explicit verification; an unsold fictional card remained described as unsold, with no generated sale price.
- Desktop (1440 px) and mobile (390 px) checked in light and dark modes. Labels, warnings, controls and buttons remain readable; no page-wide horizontal overflow on mobile. Keyboard Enter opens the form, focus moves to the labeled batch field, and focus indication is visible.

## Database rollout

Applied migrations `20260917180437_consignment_campaigns` and `20260917180743_consignment_preserve_published_history` to the documented Marketing Hub Supabase project. The local migration filenames match remote migration history. All 18 pre-existing post records retained an identical combined content fingerprint; no fictional records or staff were inserted into the live database. Anonymous execution of the campaign RPC is denied; receipt-table RLS and private access are enforced. Live PostgreSQL timezone calculations returned 48 hours for both DST test cases.

Security advisors reported no new warnings/errors. Private receipt and staff tables intentionally have RLS with no direct-access policies. The pre-existing Auth leaked-password-protection warning remains unrelated to this change: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Limits

Browser tests use local test identity, not a live staff login. A signed-in production smoke test still requires a staff session. Vercel's connector currently returns 403 for the documented team; use GitHub deployment status and public HTTP/browser evidence to verify the pushed build. No invitations, external social posts, ads or paid actions were performed. Publishing remains manual.
