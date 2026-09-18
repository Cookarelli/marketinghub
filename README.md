# Northside Marketing Hub

Team workspace for launch planning, content production, Content Radar, draft review, a shared calendar, campaign links, and results.

This repository combines the latest readable Hub interface and news aggregator with the Next.js/Supabase deployment. Text is larger, navigation has labeled buttons, and News & Content Radar has a prominent entry point.

## Run and verify

Use Node 22.13 or newer and the pnpm version in `package.json`.

```sh
pnpm install --frozen-lockfile
cp .env.example .env.local
pnpm test
pnpm run typecheck
pnpm run lint
pnpm run build
pnpm dev
```

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in `.env.local` and in the Vercel deployment environments. Both values are Supabase public application configuration. No service-role key is used by the application. Never commit credentials or staff email lists.

## Supabase

Apply the initial migration in `supabase/migrations` to an empty project. Its SQL is assembled in this order from the reviewed modules: `schema.sql`, `records.sql`, `radar.sql`, `feed.sql`, `editorial.sql`, `permissions.sql`. Tests execute these same modules in PostgreSQL using PGlite.

Provision the approved staff roster in `private.staff_access` through a trusted administrator. Each row needs an email, workspace ID, staff ID, name, title, role (`admin` or `staff`), and active flag. The workspace created by this migration is `northside-marketing`. Keep the roster out of source control. Create each person's individual Auth login through Supabase Authentication and require a verified email. No shared password or setup code grants access.

Authorization joins the verified Auth email to the current private roster on every request. Client-editable user metadata is never authoritative. Exposed tables have row-level security; application writes go through named transaction functions with checked membership, fixed workspace scope, and database-assigned actors. History tables cannot be changed by the application role. Staff can view shared assets; the private Storage bucket permits scoped uploads and short-lived downloads.

## Password recovery

The login page includes **Forgot password?**. See [password recovery setup and verification](docs/password-recovery.md) for the required Supabase redirect URL, email delivery configuration, and recovery checks.

## Content Radar

Open Content Radar, add the starter sources, then use **Refresh sources** or add a link manually. Publisher content is unverified until reviewed. Collection preserves publisher snapshots, deduplicates URLs, skips overlapping jobs, and stops stale workers after settings change. Network fetching is restricted to the reviewed publisher host list; redirects, response size, and collection time are bounded.

Save a story, edit the captions and Reel outline, choose **Needs review**, and save. An administrator can approve the unchanged draft after required sources and media permissions are recorded. Approval does not publish externally. Add an approved draft to the shared calendar. Later material edits, fact changes, and product changes invalidate approval and mark the calendar copy for review.

## Deployment and remaining activation

Import this repository into Vercel as a Next.js project and set the two environment variables. Use a protected preview for initial testing. Verify sign-in, record saving after reload, upload/download, source refresh, review, and calendar handoff before directing the team to the new URL.

The existing Hub is a separate deployment. Its records and uploaded media have not been imported into this new database. Export and review that data before migration; do not merge individual workspaces into shared data without checking the contents.

Automatic daily collection is not enabled in this migration. Staff-triggered collection is available. AI drafting, Shopify stock sync, transcription, external social publishing, and in-app video rendering are not connected. The local video-rendering helper remains available in Content studio.

## Consignment campaigns

The Marketing Calendar includes reusable five-stage consignment campaigns, schedule previews, conflict warnings, and safe rescheduling. See [workflow and deployment instructions](docs/consignment-campaigns.md). Apply the consignment migration before deploying the feature.
