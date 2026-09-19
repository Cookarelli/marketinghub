# Northside HQ

## Requests, files and publishing handoff — implemented

General requests use the same scoped record store, separate from the working editorial queue, which remains accessible under Requests. A request records its requester and requested deadline; acceptance records one durable conversion link and never copies the requested date into a production commitment. Current administrators are provisioned as request coordinators through the existing configurable permission table. Conversion, decision, linked-target creation and activity use one database transaction with retry protection.

Asset associations retain the current asset IDs, private bucket, upload/finalize endpoints and image/video limits. Explicit Reference / Draft / Final metadata classifies attached files and links; old unclassified attachments default to Reference for display and cannot silently become approved final files. Uploading a replacement creates a new immutable object. The only intentionally public brand file found in this checkout is `/favicon.svg`; it and the existing public renderer remain public through explicit static routes. Uploaded files never inherit public access from a label or project reference.

Review records a submission to the current owner, reviewer comments, exact content/record versions and a saved publishing package. Asset, caption or link edits invalidate approval and require resubmission. Internal work needs no caption; organic work needs no paid budget. Paid promotion must fit a project's approved channel allocation across deliverables. Publishing stays manual, with the assigned publisher, final files, approved copy/link, time and allocation shown together.

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
| Editorial desk (`/content-radar/editorial`) | Actual tabs: **Today’s Top 5, Stories, Editorial queue, Products, Staff**. `radar_editorial` queue/detail/product records; append-only history; private roster via RPC | Requests → Editorial queue retains this editor; the default Requests view now handles general work intake. Reuse intake of Northside originals, assignment, captions, evidence, permissions, review and calendar handoff. Editorial records retain their specialized content intake and calendar handoff; they are not copied into general requests. |
| Staff setup (`/content-radar/setup`) | Currently redirects to editorial without selecting Staff | Redirect to Requests with Staff selected. Retain administrator-only mutation rules. |
| Authentication | Individual Supabase password sign-in, verified email and active private roster; forgot/reset-password flows with recovery-session checks | Preserve behavior, cookies, recovery URLs and sign-out; update visible branding only. |

The application is Next.js App Router / React 19 / TypeScript with Tailwind 4, shadcn/Radix components and `next-themes`. Dark mode persists under `northside-color-theme`. Dates in the calendar are Chicago wall-clock values; campaign helpers reject nonexistent or ambiguous DST times. UTC audit timestamps are formatted in America/Chicago for people.

## Database, authorization, storage and integrations

- Five checked-in migrations: `20260916011251_marketing_hub`, `20260916011429_provision_approved_staff`, `20260916025113_content_calendar_september_2026`, `20260917180437_consignment_campaigns`, `20260917180743_consignment_preserve_published_history`. Inspect them; do not replay initial setup against an initialized database. `supabase/*.sql` are readable modules used by local PostgreSQL tests, not instructions to reset production. The staff-provisioning and September-calendar files are intentionally `select 1` checkpoints: their private roster and calendar contents are not reproducible from this public repository.
- `marketing_records` stores plan/post/link/metrics/clipjob/upload/asset/campaign data under the unchanged `northside-marketing` workspace. Radar has organization/source/item/draft/publication/ingestion/editorial/history tables. `private.staff_access` holds membership; `private.campaign_receipts` protects campaign retries.
- `identity()` verifies the current Auth user and confirmed email, then calls `hub_context`. Database helpers consult the current private roster. RLS scopes reads to the workspace. Mutations use checked RPCs, fixed search paths and database actors; direct application-role writes and history edits are denied. POST routes check same-origin requests. No service-role key is used.
- Editorial approval is currently **administrator-only**. Ordinary calendar status edits permit staff; consignment approval validates production tasks/assets, staff picks and verified auction facts but does **not** enforce project-owner authority or approved spending. Clip approval is a saved editing choice, not a project approval. Preserve these distinctions until the new policy is implemented transactionally.
- Private bucket `marketing-assets` permits scoped, non-overwriting uploads up to 40 MB of the existing image/video types. Finalization checks size/type; downloads use five-minute signed URLs. Preserve `/api/assets`, `/api/assets/finalize`, `/api/assets/[id]` and `/api/content-radar/media/[id]`. The HQ extension adds an authenticated `?download=1` option to the asset route. Never redirect API/media routes when retiring Radar pages.
- Working code integrations: Supabase Auth/database/Storage, source collection with allowlisted hosts and bounded fetching, local renderer downloads, exports and browser UTM helper. Existing source collection remains staff-triggered; no cron is configured.
- Shopify, GA4, ad accounts, AI generation, automatic transcription, in-app rendering and external social publishing are **not connected in the inspected application**. Preserve manual publishing. In-app notifications are the product decision; toasts currently report action outcomes, but there is no durable notifications table or inbox.
- Repository deployment documentation names Vercel project `marketinghub-7vl1`, team `steves-projects-e37a4ef4`, URL `https://marketinghub-7vl1.vercel.app`, and Supabase project `sjbjotfzsnaolecxklxr`. There is no checked-in Vercel project override or local `.vercel/project.json`. The two existing public Supabase environment variable names remain unchanged. Prior documents report a Vercel connector authorization problem; this inspection does not claim a fresh production deployment or signed-in test.

## Shell implementation

Primary navigation, in order: **Today, Projects, Calendar, Requests, Assets**. Use a shared authenticated shell with Northside HQ branding, a skip link, clear active state, large labeled controls, persistent theme, responsive mobile navigation and a visible America/Chicago time-zone label.

- Today summarizes actual saved calendar work (due today, review, ready for manual publishing) and links to existing editors. No invented tasks, people, projects or activity. Loading/failure must never look like an empty successful workspace.
- Projects groups the saved launch plan and consignment campaigns. Existing launch planning, tracked links and results remain secondary tools. Reuse the existing campaign editor and production workflow.
- Requests now presents general production intake in the shared record store. The working editorial intake/review queue remains a secondary view, with its existing records and specialized checks. No editorial records are duplicated.
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
| `/content-radar/editorial` | `/requests?view=editorial` |
| `/content-radar/setup` | `/requests?view=staff` |

Fragments are handled client-side because HTTP requests do not contain them. Page redirects must be exact, never a blanket `/content-radar` replacement that intercepts API or attached-media access. Keep unknown paths as 404s. New authenticated pages must receive the existing session-refresh proxy and server-side membership check.

## Complete first-release requirements

The release flow is request → scoped project with owner (approved budget for paid promotion) → assigned production tasks/deliverables with assets → owner review/revision → scheduled, manually published work with recorded outcome → archive/reporting. Every stage must persist, survive reload, enforce permissions on the server and surface relevant in-app notifications.

Required additive work after the shell:

1. Define durable projects and general requests, including owner, requestor, brief, dates, status, budget currency/amount, budget approval actor/time/version, and deliverable links. Adapt existing campaigns and editorial IDs by reference; avoid copying records or silently assigning owners/budget approvals.
2. Define budget-approval authority separately from deliverable approval. Project owners approve their own project's deliverables only within the approved budget; absent/stale approvals or over-budget changes require budget review. Enforce membership, ownership, budget version and committed spend atomically in database transactions for **every** write path. UI disabling alone is insufficient. Preserve existing consignment evidence requirements.
3. Add versioned project/deliverable approval history and revision states; material changes invalidate affected approvals. Preserve published facts and historical dates. Backfill existing records only with explicit mappings and a reviewed migration.
4. Complete general request triage, production assignments, required asset/version links and project views using the working editorial/calendar/campaign components where applicable.
5. Provide manual-publishing confirmation with actor, actual time and destination link. The current editorial calendar copies cannot be marked published through generic record writes; design an authorized handoff/confirmation path rather than bypassing the guard.
6. Add durable in-app notifications for assignments, review requests, revisions, approvals and relevant due dates, with per-user read state and safe deduplication. No email, SMS, push or social automation.
7. Verify end to end with owner/non-owner/admin/revoked/cross-workspace cases, budget overspend and concurrent edits, attachment access, retries, reload persistence, Chicago DST, keyboard use, light/dark and mobile. Do not label the first release complete until these pass.

No database migration, data reset, record deletion, production deployment, new service, or infrastructure change is part of this shell step.

## Shared projects and deliverables — implementation design

Canonical HQ projects and deliverables use new `project` and `deliverable` kinds in the existing organization-scoped `marketing_records` store. A deliverable owns a separate confirmation object for every destination; dates alone never change publishing state. Production deadlines and intended publication times are distinct Chicago wall-clock values. Comments and append-only activity use scoped tables; attachments keep the existing private storage routes.

Legacy campaigns and ordinary calendar posts are adopted explicitly, once, by reference. Adoption preserves the original rows byte-for-byte as read-only history and creates a unique canonical HQ link. Adopted rows disappear from the old editors and appear in HQ; database guards also prevent stale legacy clients from writing them. Campaign adoption includes its posts and retains the existing auction-evidence checks and review controls. Historical status, dates and evidence remain visible, but never become new HQ approvals or platform confirmations. Unknown owners, briefs, deadlines and effort remain missing. Recurring templates and editorial-managed calendar copies remain in their current working editors until a dedicated handoff is implemented.

Project owners approve deliverables; a standalone deliverable names its approver. Budget approval is a separate configurable `budget_approve` capability, initially granted to existing Northside staff IDs `steve` and `joey`. No email or role automatically authorizes budget changes. Administrators manage capability assignments; owners allocate only within the approved amount. Database transactions validate the current roster, organization, owner, version, budget and evidence. Material edits require renewed approval. Recorded publishing facts are retained permanently.

This additive migration is prepared and tested locally; applying it to the existing database is a separate rollout step. No production infrastructure, repository identity, authentication or storage configuration is changed. General request handoff is implemented in the next additive migration described below. Durable per-user in-app notifications and the editorial-copy handoff remain first-release follow-up work.

## Repository rename dependencies — deferred

Keep `Cookarelli/marketinghub`, package identity, Git remote, Vercel link/domain and Supabase identifiers unchanged. A later repository rename needs review of clone remotes, Vercel Git integration/repository permissions, GitHub Actions/webhooks/checks, documentation links/badges, external tooling and saved checkout paths. A domain change separately needs Supabase Auth Site URL/redirect allowlist (especially `/reset-password`), user bookmarks and any external callback URLs. Do not rename the workspace or bucket to match the product label: those are data/access identities, not branding.

## Shell verification record (previous milestone)

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


## Shared model: implemented behavior and rollout

The shared model now provides project list/detail, project creation and editing, all four project types and lifecycle states, members, event/release and auction date fields, approved USD budgets and channel allocations. Deliverables support standalone or project work, one accountable owner, optional contributors, approver selection for standalone work, separate production/publication dates, format, destination platforms, copy/link, effort/hours, blocked reason/resolver, saved private assets and reference links. Comments and full saved-version activity snapshots persist in PostgreSQL.

Routes are `/projects`, `/projects/[id]` and `/projects/work/[id]`, all inside the authenticated shell and session-refresh proxy. Today and Calendar read the same deliverables; no second HQ calendar or publication store is created. Original launch planning, reporting, tracked links, unadopted campaigns, editorial copies, templates and asset tools remain reachable. Adopted campaigns/posts are filtered out of old editors, and SQL guards reject stale legacy writes or additional legacy posts against adopted campaigns.

### Ownership and review

- Active organization staff may read shared records and comment. Owners or administrators edit project details; only the current project owner changes channel allocations. Owners and project members can add work. Assigned owners, contributors, project members, approvers and administrators may edit production content. Assignment/approver/project changes on existing work require its current approver or an administrator; moving work also requires membership in the destination project. A person cannot escape approval by moving their own deliverable to standalone work.
- Only the project owner or designated standalone approver can approve **Needs review → Ready**. Administrators have no automatic approval override. Project work requires an active project and its current owner. Organic work requires no budget approval; paid promotion must fit an approved project channel allocation, including other deliverables. Nonpublishing work finishes **Ready → Done**. Publishing work stays Ready while each destination independently progresses.
- Content edits invalidate approval. Project changes, including budget/allocation changes, atomically return pending Ready deliverables to Needs review. Completed work and recorded publication facts remain historical. Version checks and the existing organization transaction lock prevent stale edits and concurrent overspending.
- Scheduling requires the exact platform time plus a human confirmation that scheduling occurred on that platform. Publication requires an actual Chicago time, explicit human confirmation and an HTTPS live URL, or a recorded explanation when a URL is unavailable. Recording Facebook publication leaves Instagram Planned until explicitly recorded. Confirmed schedules must be cancelled on the actual platform and recorded as cancelled before content editing. Published content and confirmation facts are immutable; comments and new follow-up deliverables preserve corrections without rewriting history.
- The existing consignment review component and database verifier are reused for adopted production. Finished assets, outstanding tasks, staff picks, current auction facts, deadline/lot-link checks and final result evidence remain approval requirements. Changing auction facts invalidates their previous attestation.

### Legacy mapping

| Existing data | HQ mapping | Deliberately unresolved |
| --- | --- | --- |
| Campaign `name`, active staff `owner`, `opening`, `closing` | Weekly Auction title, owner and dates | Brief, approved budget, members and allocations are not invented. |
| Campaign batch/platform/featured cards | Editable auction facts; original campaign row retained | Fresh verification is required when facts change. |
| Calendar title/caption/date/platforms/references | Deliverable title/copy/intended time/platforms/references | Production deadline, effort, format, instructions and standalone approver remain missing. Unknown/inactive owners remain unassigned. Invalid/ambiguous dates remain only in preserved history. |
| Calendar tasks, assets and verification | Preserved original snapshot and reused evidence controls | Legacy free-text asset references are shown as historical references; new attachments select real organization assets. |
| `draft`, `review`, `approved`, `published` | Preserved verbatim in historical snapshot; new HQ work begins To do with Planned destinations | No inferred owner approval, scheduled confirmation, actual publication time, live URL or budget approval. |
| Editorial-managed posts / weekly templates | Continue in existing Requests / Calendar editors | No automatic handoff or recurrence migration. These are explicitly excluded from adoption. |

### Additive migration and operating boundaries

Apply the pending migrations in order after the existing consignment migrations: `20260919014854_northside_hq_projects_deliverables.sql`, then `20260919023059_northside_hq_requests_review_handoff.sql`. Skip any migration already applied; inspect the remote migration history before rollout. Both are transaction-wrapped, repeatable, create no fictional records and perform no automatic adoption. `supabase/hq.sql` and `supabase/hq-workflow.sql` are their respective identical reviewed modules. The old module is intentionally retained as the historical implementation; the second replaces relevant functions without rewriting old rows. Do not replay the initial schema or reset the database. Existing remote names, deployment links, bucket, membership roster and environment variables stay unchanged.

The migration seeds `budget_approve` for existing Northside staff IDs `steve` and `joey`. Runtime checks consult the permission table. Administrators can grant/revoke it in **Projects → Workspace permissions → Budget approval**. Reapplying the migration never re-enables a revoked permission. If those staff IDs do not yet exist when it runs, use the permission controls after provisioning; do not grant authority by matching an email address.

No migration or deployment was applied to production in this implementation. Existing production migration state and real signed-in Storage/integration behavior require a rollout smoke test. Durable per-user in-app notifications and editorial-copy handoff remain first-release follow-up work; this change does not claim the full release is complete.

### Shared-model verification (previous milestone)

- 36 automated tests pass, including 11 focused HQ tests executing actual PostgreSQL functions, table grants and RLS in PGlite. Coverage includes signed-out/unconfirmed/revoked/cross-organization access, owner versus administrator approval, configurable budget permission/revocation, allocation bounds, stale writes, missing information, blocked work, assignment escalation, standalone Done, Chicago DST, independent platform confirmations, unchanged legacy records, retained consignment evidence gates, migration reapplication and database restart persistence.
- Browser verification used fictional local records through the actual Next.js forms, API routes and SQL RPC. Created an active project, approved its budget, allocated a channel, added a comment, created a deliverable, advanced production, approved it, confirmed Facebook scheduling and recorded its live publication. Reload retained Facebook Published and Instagram Planned. Today/Calendar linked the canonical work. Cross-origin mutation was rejected; anonymous project/API/asset access was denied.
- A second browser flow verified standalone approver selection, Premium effort/estimated hours, a blocked approval denial, editing, the thirteenth saved asset and reference links, and Done after reload. Campaign adoption created five HQ deliverables with missing effort and no approvals/confirmations, left every original campaign/post byte-for-byte unchanged, removed its old editor and retained the actual production checklist.
- Desktop and 390/320-pixel mobile checks retained all five primary navigation links with no horizontal overflow or browser runtime errors. Dark mode persisted after reload. Existing asset/authentication code remains in place.
- `pnpm run build`, `pnpm run typecheck` and `git diff --check` pass. `pnpm run lint` passes with the same three pre-existing image/full-page-navigation advisories and no errors. No dependency, environment, authentication, storage or deployment configuration was changed.


## Requests, materials, review and manual handoff details

- `/requests` has four intake questions; `/requests/[id]` shows requester, status, requested deadline, decision actor/time/reason, linked work, comments and activity. Accepted and declined requests are immutable. Declining requires a reason. Requesters or coordinators may edit New requests; only enabled `coordinate_requests` staff can decide. The new migration provisions existing active administrators once; administrators configure or revoke coordinators independently of budget authority in Projects. Reapplying does not re-enable a revoked permission.
- A coordinator chooses a new or existing project or standalone deliverable. Acceptance creates one durable `conversion` reference on the original request. New work copies its brief and reference attachments, explicitly chosen owner/type/approver/effort, and no committed deadline. Existing work is linked without changing its dates, content or approval. Its detail derives original-request links from the canonical request. The organization lock, record version and decision UUID make retries atomic and prevent double conversion; a reused decision UUID with different inputs is rejected.
- Files use the existing private `marketing-assets` bucket, endpoints, 40 MB limit and six MIME types: JPEG, PNG, WebP, MP4, QuickTime/MOV and WebM. Other formats can be linked externally. Upload completion is verified against Storage before creating the asset. A failed upload stays visible with Retry/Discard, blocks form submission and keeps its ticket so a lost response cannot create another attachment. Successful uploads must still be saved into the form's record. Discarding an unfinished association does not delete existing storage or records.
- Attachments use existing immutable asset IDs and explicit `assetRoles`/`linkRoles`: Reference, Draft or Final. Requests contain reference material only. Missing legacy classifications display Reference. Previews use authenticated image/video redirects, with a download fallback; external links open directly and are not fetched by the server. Download signing remains membership-scoped, private/no-store and five minutes. The static `/favicon.svg` is the explicit public brand allowlist in `lib/asset-policy.ts`; the existing `/render_package.py` utility stays public. No uploaded brand library or anonymous asset policy existed in the inspected checkout. Neither a `public` data flag nor linking a file to a request grants anonymous access.
- Submission records the sender, current reviewer, timestamp, content version and submitted record version. Only the project owner or designated standalone approver can approve or request changes. Changes require a comment and return production to In progress. Approval stores reviewer/time/comment, reviewed version, approved record version, content version and the exact final-file IDs, final external links, caption, destination, platforms, publisher, intended time and promotion allocation. Review comments are also appended to the record discussion.
- Saving any deliverable content edit conservatively clears approval/submission and increments content version. Edited reviewed/Ready/Done work returns to In progress and must be submitted again. This includes replacing a final file, changing its classification, changing caption or destination link. Existing schedules must first be cancelled and recorded; published content cannot be rewritten. Historical approval rows are left untouched, but lack a verified package and cannot authorize a new handoff until explicitly edited/submitted/reviewed.
- Required output is selected on each deliverable. Internal tasks do not require captions or destinations. Publishing needs an assigned publisher, format, platforms and intended time, plus only its selected final-file/caption requirements (or a destination link for link-only work). Organic work requires no zero-dollar budget ceremony. Paid work needs a positive allocation from an approved project channel; the project owner controls the amount. All allocations in that channel are summed, and a project channel cannot be reduced below committed deliverable allocations.
- The approved publishing package offers final-file downloads, approved caption copying with visible fallback, destination opening, assigned publisher/platforms/time and approved promotion allocation. The assigned publisher or current approver records scheduling only after explicit confirmation on the actual platform. Publication requires a real time and live URL or explanation. Each destination remains independent. No social SDKs, credentials, queues, API integrations or automatic publishing were added.
- Activity and comments remain attached to requests/projects/deliverables. Today exposes production reviews and blocked/missing work through existing shared-record views. No separate chat product was introduced.

### Rollout boundaries

No database, storage policy, bucket, deployment connection, authentication configuration or production infrastructure was changed remotely. The additive migration and application must roll out together, after checking migration history. Production credentials are absent locally, so actual hosted Storage/provider behavior and the production roster were not tested. All browser data is fictional and isolated outside the repository. The initial inventory and earlier verification sections above document previous milestones; current behavior is defined by this section and the second HQ migration.

### Current verification — request and handoff phase

- `pnpm test`: **50 passed**, including 14 new focused request/review/storage/upload checks. They execute real PostgreSQL functions and grants/RLS in PGlite, plus upload retry behavior against controlled responses. Coverage includes all four conversion targets, decision UUID retries, competing decisions, failed-conversion rollback, requester identity, coordinator permission independent of budget authority, decline reasons, private asset validation/isolation, replacement/caption/link invalidation, mandatory revision comments, exact approved versions/packages, organic approval without budgets, internal tasks without captions, paid channel commitments, publisher authority, independent destinations, historical approval preservation, repeated migration and restart persistence. The original HQ test suite explicitly verifies its immutable historical migration; the new suite verifies the current additive extension.
- The actual Next.js browser → API → PostgreSQL path passed using fictional local data and a local Storage adapter: request/file/link capture, visible upload failure, save blocked during failed upload, successful same-ticket retry, standalone conversion, requested versus committed dates, review changes, revised submission/approval, approved caption copy, final-file download and media preview, approval invalidation after copy changes, explicit platform scheduling, actual publication/live URL, comments and reload persistence. Facebook remained Published while Instagram remained Planned. No browser runtime errors occurred.
- Anonymous requests to internal HQ and private asset endpoints returned 401, while `/favicon.svg` remained public. SQL tests denied unrelated-organization file/record/history reads, anonymous table access, private-helper execution and storage overwrites. The retired editorial page still redirected to its preserved editorial queue and fixture records.
- The compact request form and attachment expansion passed at 320/390 px with five usable navigation links and no horizontal overflow; dark mode persisted after reload. Final dark/light request and publishing package screenshots are held in the task outputs, outside the repository.
- `pnpm typecheck`, `pnpm lint` and `git diff --check` pass. Lint retains only the same three existing advisories for a private image and full-page authentication navigation. The production build passes with the new request detail route and preserved API/media routes. No dependency, package/repository identity, environment, authentication or deployment configuration changed.

Verification limits: this does not apply migrations or test production. Local Storage transport is an adapter; hosted Supabase signing, upload/download behavior and the real roster require a signed-in rollout smoke test. PGlite transaction tests prove serialized conflict handling, not a load test of concurrent hosted connections. No real records, messages, social posts or infrastructure were modified.
