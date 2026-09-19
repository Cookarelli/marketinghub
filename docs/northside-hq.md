# Northside HQ

## Inspection and scope — 18 September 2026

This document was written before the shell changes. The implementation starts from `c866f51` on the existing `Cookarelli/marketinghub` repository, including the newly merged password recovery flow. Work is on `codex/northside-hq`. Repository history, deployment connections, environment variable names, workspace IDs, storage keys, and record IDs stay in place.

The requested first implementation step is the inventory, application shell, and Northside HQ branding. **This step is not the complete first release.** The first release must include the entire workflow below; the missing data model and authorization controls are release blockers, not optional follow-ups or simulated features.

Read before implementation: root `AGENTS.md`; installed Next.js 16.3.4 documentation for layouts/pages, Proxy, redirects, and metadata; installed Next.js and Supabase skills; current Supabase SSR and RLS documentation and changelog; README and deployment, campaign, verification, and password recovery documents. No other repository AGENTS files were found.

## What actually exists

| Existing surface | Implementation and persisted data | Reuse / new location |
| --- | --- | --- |
| Launch plan (`/#launch`, initial default) | `app/hub.tsx`, `StrategySummary`; `marketing_records` kind `plan`, ID `launch`; proposed budget scenarios, campaign ID, opening details, forecasts | Projects → Launch plan. A saved proposal is **not** an approved project budget. Keep scenario and strategy helpers. |
| Content studio (`/#studio`) | Private upload/finalize/download, video preview, transcript matching, clip windows and review, saved `asset` and `clipjob` records, editing recipe and public Python renderer | Assets → Library & studio. Preserve every asset ID, key, media endpoint, saved job, and renderer URL. Show all saved assets, not just the first 12. |
| Calendar (`/#calendar`) | `ContentCalendar`, saved `post` records; dated entries, recurring Tuesday templates, CSV, editorial handoff, status editing | Calendar. Keep dated and recurring records intact. |
| Consignment campaigns (inside Calendar) | `ConsignmentCampaign`, `campaign` records plus posts with stable `consignment` identity; five stages, active staff assignment, multi-platform plans, tasks, asset references, rescheduling, verification, retries and conflict detection | Projects overview reuses these campaign records and the **same** campaign editor; Calendar retains scheduling and production editing. Do not create a second campaign store. |
| Tracking (`/#tracking`) | UTM builder, registered read-only browser tool, saved `link` records, clipboard and CSV | Projects → Tracked links. Preserve URL validation and exports. |
| Performance (`/#performance`) | Saved `metrics` records, filters, manual JSON import/export and reconciled totals | Projects → Results. Keep manual reporting explicitly labeled. |
| Build plan (`/#roadmap`) | Static `ROADMAP` constant and learning-loop copy; no distinct database table or saved records | Retire from navigation; old hash opens Projects. Preserve original source/history and useful clip-learning ideas here. Automated transcription, rendering and model training are future integrations, not core-release dependencies. |
| Content Radar (`/content-radar`) | Actual tabs: **Feed, Releases, Chase Cards, Drafts, Sources**. Sources, ingestion runs, stories, draft summaries, publisher snapshots and workflow history in `radar_*` tables; staff-triggered bounded publisher fetches | Assets → Research & sources. Keep source management, provenance, verification, saved ideas, filters, pagination, ingestion safeguards and history. Retire only its top-level identity. |
| Editorial desk (`/content-radar/editorial`) | Actual tabs: **Today’s Top 5, Stories, Editorial queue, Products, Staff**. `radar_editorial` queue/detail/product records; append-only history; private roster via RPC | Requests opens the existing Editorial queue; other editorial views remain secondary. Reuse intake of Northside originals, assignment, captions, evidence, permissions, review and calendar handoff. This is content intake, not yet a general project request model. |
| Staff setup (`/content-radar/setup`) | Currently redirects to editorial without selecting Staff | Redirect to Requests with Staff selected. Retain administrator-only mutation rules. |
| Authentication | Individual Supabase password sign-in, verified email and active private roster; forgot/reset-password flows with recovery-session checks | Preserve behavior, cookies, recovery URLs and sign-out; update visible branding only. |

The application is Next.js App Router / React 19 / TypeScript with Tailwind 4, shadcn/Radix components and `next-themes`. Dark mode persists under `northside-color-theme`. Dates in the calendar are Chicago wall-clock values; campaign helpers reject nonexistent or ambiguous DST times. UTC audit timestamps are formatted in America/Chicago for people.

## Database, authorization, storage and integrations

- Five checked-in migrations: `20260916011251_marketing_hub`, `20260916011429_provision_approved_staff`, `20260916025113_content_calendar_september_2026`, `20260917180437_consignment_campaigns`, `20260917180743_consignment_preserve_published_history`. Inspect them; do not replay initial setup against an initialized database. `supabase/*.sql` are readable modules used by local PostgreSQL tests, not instructions to reset production. The staff-provisioning and September-calendar files are intentionally `select 1` checkpoints: their private roster and calendar contents are not reproducible from this public repository.
- `marketing_records` stores plan/post/link/metrics/clipjob/upload/asset/campaign data under the unchanged `northside-marketing` workspace. Radar has organization/source/item/draft/publication/ingestion/editorial/history tables. `private.staff_access` holds membership; `private.campaign_receipts` protects campaign retries.
- `identity()` verifies the current Auth user and confirmed email, then calls `hub_context`. Database helpers consult the current private roster. RLS scopes reads to the workspace. Mutations use checked RPCs, fixed search paths and database actors; direct application-role writes and history edits are denied. POST routes check same-origin requests. No service-role key is used.
- Editorial approval is currently **administrator-only**. Ordinary calendar status edits permit staff; consignment approval validates production tasks/assets, staff picks and verified auction facts but does **not** enforce project-owner authority or approved spending. Clip approval is a saved editing choice, not a project approval. Preserve these distinctions until the new policy is implemented transactionally.
- Private bucket `marketing-assets` permits scoped, non-overwriting uploads up to 40 MB of the existing image/video types. Finalization checks size/type; downloads use five-minute signed URLs. Keep `/api/assets`, `/api/assets/finalize`, `/api/assets/[id]` and `/api/content-radar/media/[id]` unchanged. Never redirect API/media routes when retiring Radar pages.
- Working code integrations: Supabase Auth/database/Storage, source collection with allowlisted hosts and bounded fetching, local renderer downloads, exports and browser UTM helper. Existing source collection remains staff-triggered; no cron is configured.
- Shopify, GA4, ad accounts, AI generation, automatic transcription, in-app rendering and external social publishing are **not connected in the inspected application**. Preserve manual publishing. In-app notifications are the product decision; toasts currently report action outcomes, but there is no durable notifications table or inbox.
- Repository deployment documentation names Vercel project `marketinghub-7vl1`, team `steves-projects-e37a4ef4`, URL `https://marketinghub-7vl1.vercel.app`, and Supabase project `sjbjotfzsnaolecxklxr`. There is no checked-in Vercel project override or local `.vercel/project.json`. The two existing public Supabase environment variable names remain unchanged. Prior documents report a Vercel connector authorization problem; this inspection does not claim a fresh production deployment or signed-in test.

## Shell implementation

Primary navigation, in order: **Today, Projects, Calendar, Requests, Assets**. Use a shared authenticated shell with Northside HQ branding, a skip link, clear active state, large labeled controls, persistent theme, responsive mobile navigation and a visible America/Chicago time-zone label.

- Today summarizes actual saved calendar work (due today, review, ready for manual publishing) and links to existing editors. No invented tasks, people, projects or activity. Loading/failure must never look like an empty successful workspace.
- Projects groups the saved launch plan and consignment campaigns. Existing launch planning, tracked links and results remain secondary tools. Reuse the existing campaign editor and production workflow.
- Requests presents the working editorial intake/review queue, with its existing records and secondary views. Do not invent a parallel request store.
- Assets preserves uploads, editing jobs, exports and media access, with research/source tools as a secondary route.

Compatibility plan:

| Old URL | Destination |
| --- | --- |
| `/`, `/#today` | `/today` |
| `/#launch` | `/projects#launch` |
| `/#studio` | `/assets` |
| `/#calendar` | `/calendar` |
| `/#tracking` | `/projects#tracking` |
| `/#performance` | `/projects#performance` |
| `/#roadmap` | `/projects` |
| `/content-radar` | `/assets/research` |
| `/content-radar/editorial` | `/requests` |
| `/content-radar/setup` | `/requests?view=staff` |

Fragments are handled client-side because HTTP requests do not contain them. Page redirects must be exact, never a blanket `/content-radar` replacement that intercepts API or attached-media access. Keep unknown paths as 404s. New authenticated pages must receive the existing session-refresh proxy and server-side membership check.

## Complete first-release requirements

The release flow is request → scoped project with owner and approved budget → assigned production tasks/deliverables with assets → owner review/revision → scheduled, manually published work with recorded outcome → archive/reporting. Every stage must persist, survive reload, enforce permissions on the server and surface relevant in-app notifications.

Required additive work after the shell:

1. Define durable projects and general requests, including owner, requestor, brief, dates, status, budget currency/amount, budget approval actor/time/version, and deliverable links. Adapt existing campaigns and editorial IDs by reference; avoid copying records or silently assigning owners/budget approvals.
2. Define budget-approval authority separately from deliverable approval. Project owners approve their own project's deliverables only within the approved budget; absent/stale approvals or over-budget changes require budget review. Enforce membership, ownership, budget version and committed spend atomically in database transactions for **every** write path. UI disabling alone is insufficient. Preserve existing consignment evidence requirements.
3. Add versioned project/deliverable approval history and revision states; material changes invalidate affected approvals. Preserve published facts and historical dates. Backfill existing records only with explicit mappings and a reviewed migration.
4. Complete general request triage, production assignments, required asset/version links and project views using the working editorial/calendar/campaign components where applicable.
5. Provide manual-publishing confirmation with actor, actual time and destination link. The current editorial calendar copies cannot be marked published through generic record writes; design an authorized handoff/confirmation path rather than bypassing the guard.
6. Add durable in-app notifications for assignments, review requests, revisions, approvals and relevant due dates, with per-user read state and safe deduplication. No email, SMS, push or social automation.
7. Verify end to end with owner/non-owner/admin/revoked/cross-workspace cases, budget overspend and concurrent edits, attachment access, retries, reload persistence, Chicago DST, keyboard use, light/dark and mobile. Do not label the first release complete until these pass.

No database migration, data reset, record deletion, production deployment, new service, or infrastructure change is part of this shell step.

## Repository rename dependencies — deferred

Keep `Cookarelli/marketinghub`, package identity, Git remote, Vercel link/domain and Supabase identifiers unchanged. A later repository rename needs review of clone remotes, Vercel Git integration/repository permissions, GitHub Actions/webhooks/checks, documentation links/badges, external tooling and saved checkout paths. A domain change separately needs Supabase Auth Site URL/redirect allowlist (especially `/reset-password`), user bookmarks and any external callback URLs. Do not rename the workspace or bucket to match the product label: those are data/access identities, not branding.

## Verification record

Implemented the authenticated shared shell and all five primary routes, Northside HQ metadata and sign-in/recovery branding, Today’s real-record summary, Projects’ existing campaign editor and secondary tools, Requests’ existing editorial queue, Assets’ complete library and research route, exact page redirects and legacy-fragment handling. Added a skip link, route loading/error states, mobile navigation and explicit Chicago labels. Requests uses the actual returned staff roster for assignment names and choices. The old static roster is not used to decide the displayed assignee. No dependencies were added or changed.

Final repository checks:

- `pnpm run build`: passed, including all new routes and the preserved API/media/recovery routes.
- `pnpm run typecheck`: passed.
- `pnpm run lint`: zero errors; the same three pre-existing warnings (private asset `<img>` and intentional full-page sign-in/sign-out navigation).
- `pnpm test`: 25 passed. Includes existing PostgreSQL authorization, campaign transactions, history/persistence, review safeguards, parsers, DST and recovery SDK tests; new checks cover old bookmarks and Chicago midnight/Today calculations.
- `git diff --check`: passed. Database modules, migrations, API handlers, package identity/lockfile, storage/auth helpers and deployment settings are unchanged.

Browser evidence used fictional data in a separate localhost PGlite PostgreSQL adapter, running the actual SQL modules, application APIs and components. There is no test route, test login bypass or fixture in the application repository. The adapter and browser state live outside the repository in this task’s scratch directory.

- All six main/secondary pages rendered at desktop 1440 px and mobile 390/320 px with exactly five primary navigation links, one main landmark and one page heading. Fixed asset-studio minimum-width overflow found on mobile.
- Verified all six old Hub hash bookmarks and all three retired Radar page routes. Staff setup selects Staff. Project secondary tabs follow browser Back/Forward.
- All 13 fixture uploads were available, including the thirteenth previously hidden by the 12-item display cap. Both asset endpoint formats still return private signed redirects for authorized sessions and reject anonymous access.
- Every new workspace page redirects an anonymous session to sign-in. No fixture content is exposed by the anonymous page response.
- Navigation/read-only checks preserved all fixture marketing records byte-for-byte. A fictional request note saved through the real application API and PostgreSQL RPC and remained visible after reload and data loading.
- Light/dark selection persisted after reload; the keyboard skip link focused main content. No browser runtime errors were recorded. Preview screenshots contain fictional content only.

Limits: production was not deployed, queried or modified. A real signed-in production smoke test (including actual Storage uploads/downloads, live source refresh and recovery email delivery) was not performed. Existing infrastructure credentials and staff sessions were not present in this local checkout. Current production migration state and external integration health remain outside this local verification. The complete first-release requirements above remain open; this shell must not be presented as the finished approvals/budget/notifications workflow.
