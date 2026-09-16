# Deployment checkpoint — 16 September 2026

## Completed

- Migrated the current readable Hub and full staff-triggered Content Radar from Sites/D1/R2 to Next.js, Supabase Postgres, Auth, and private Storage.
- Retained the earlier launch strategy summary and $5,000 default scenario; saved scenarios remain respected.
- Six PostgreSQL/parser tests passed. Production build and TypeScript passed. Lint has zero errors and three advisory warnings (one image optimization and two intentional full-page auth navigations).
- Supabase project `sjbjotfzsnaolecxklxr` has the schema and private bucket. Seven approved staff roster entries were provisioned, including one administrator. Staff addresses are absent from source control.
- Supabase security advisor reported no errors or warnings. One informational finding is expected: the private roster has RLS with no direct-access policy, and is only accessed through checked private functions.

## Live deployment verified; staff login pending

- Live Hub: https://marketinghub-7vl1.vercel.app
- Vercel project: `marketinghub-7vl1` under `steves-projects-e37a4ef4`.
- GitHub reported a successful Vercel build for source commit `d8c7e69297846395580d824e5d3859b7f30647ac`; deployment inspector: https://vercel.com/steves-projects-e37a4ef4/marketinghub-7vl1/ATmdPXiK3u4W95JCLN7bqLMVQ1P7
- After the administrator added both public Supabase configuration variables and redeployed, the served login bundle contains the expected project URL and a publishable key.
- Direct unauthenticated HTTP checks confirm `/` redirects to `/login`, the login page returns 200, and `/api/records` returns 401 with a sign-in message. The previous setup-required 503 is resolved.
- These checks do not verify a signed-in session or writes. Supabase still has zero Auth users and seven active roster entries.

The Vercel connector still returns 403 for the team. Public HTTP responses and GitHub's deployment status provided the evidence above; project environment settings and build logs remain inaccessible through that connector.

## Earlier preview

Vercel accepted a **preview** deployment:

- Preview: https://marketinghub-400wuue09-steves-projects-e37a4ef4.vercel.app
- Inspector: https://vercel.com/steves-projects-e37a4ef4/marketinghub/2msNxWAHNAqCVoPTuoZy3qS7EEHz
- Deployment: `dpl_2msNxWAHNAqCVoPTuoZy3qS7EEHz`
- Scope: `steves-projects-e37a4ef4` (`team_iPL9ti94DMgRhfyzvbgjzZdG`)

The creation response was INITIALIZING. Follow-up status and preview-access requests received 403. This earlier preview is separate from the current `marketinghub-7vl1` deployment above; its final status was not verified.

The earlier preview upload included an untracked environment file with the Supabase URL and public publishable key. The current repository-based deployment uses project environment variables. No environment values are tracked in the repository.

## GitHub source repository

Target: https://github.com/Cookarelli/marketinghub

GitHub was reconnected and repository write access was verified. The prepared application, database migrations, tests, and setup documentation are included in this source revision. No credentials or private staff contact list are tracked.

## Next activation steps

1. Create the administrator's individual Supabase Auth account, then the remaining approved staff accounts. A fresh database check confirms **zero Auth users** and seven active roster entries; roster approval alone is not a login. Confirm approved email identities and set individual passwords through Supabase Auth. No invitation messages were sent.
2. Test real sign-in, saving after reload, asset upload/download, publisher refresh, review, and calendar handoff on the new deployment before team rollout.
3. Resolve Vercel connector team authorization for future access to settings and logs.
4. Review/export records and media from the existing Hub before importing them into the new shared workspace. Existing production records and uploads were not changed or transferred.
5. Enable a scheduled collection job only after the staff-triggered collection flow is verified. This deployment contains no active cron schedule.

The old live Hub remains unchanged. AI generation, Shopify synchronization, automatic transcription and external publishing remain unconnected.
