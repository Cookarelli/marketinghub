# Deployment checkpoint — 16 September 2026

## Completed

- Migrated the current readable Hub and full staff-triggered Content Radar from Sites/D1/R2 to Next.js, Supabase Postgres, Auth, and private Storage.
- Retained the earlier launch strategy summary and $5,000 default scenario; saved scenarios remain respected.
- Six PostgreSQL/parser tests passed. Production build and TypeScript passed. Lint has zero errors and three advisory warnings (one image optimization and two intentional full-page auth navigations).
- Supabase project `sjbjotfzsnaolecxklxr` has the schema and private bucket. Seven approved staff roster entries were provisioned, including one administrator. Staff addresses are absent from source control.
- Supabase security advisor reported no errors or warnings. One informational finding is expected: the private roster has RLS with no direct-access policy, and is only accessed through checked private functions.

## Deployment created; remote verification blocked

Vercel accepted a **preview** deployment:

- Preview: https://marketinghub-400wuue09-steves-projects-e37a4ef4.vercel.app
- Inspector: https://vercel.com/steves-projects-e37a4ef4/marketinghub/2msNxWAHNAqCVoPTuoZy3qS7EEHz
- Deployment: `dpl_2msNxWAHNAqCVoPTuoZy3qS7EEHz`
- Scope: `steves-projects-e37a4ef4` (`team_iPL9ti94DMgRhfyzvbgjzZdG`)

The creation response was INITIALIZING. Follow-up status and preview-access requests received 403: the connected Vercel account is not authorized for that scope. **A successful live build has not been verified.** No production deployment was requested.

The preview upload included an untracked environment file with the Supabase URL and public publishable key. Future repository-based deployments need those two variables configured in Vercel project settings; the keys are not included in this archive.

## GitHub source repository

Target: https://github.com/Cookarelli/marketinghub

GitHub was reconnected and repository write access was verified. The prepared application, database migrations, tests, and setup documentation are included in this source revision. No credentials or private staff contact list are tracked.

## Next activation steps

1. Vercel was reconnected. Its deployment tools have not yet become available in the active session. Inspect the existing deployment under the scope above before creating another.
2. Connect the GitHub repository to the Vercel project for future deploys and configure both Supabase environment variables.
3. Create individual Supabase Auth accounts for the approved staff. There are currently **zero Auth users**; roster approval alone is not a login. Complete email verification and set individual passwords. No invitation messages were sent.
4. Test real sign-in, saving after reload, asset upload/download, publisher refresh, review, and calendar handoff on the protected preview.
5. Review/export records and media from the existing Hub before importing them into the new shared workspace. Existing production records and uploads were not changed or transferred.
6. Enable a scheduled collection job only after the staff-triggered collection flow is verified. This deployment contains no active cron schedule.

The old live Hub remains unchanged. AI generation, Shopify synchronization, automatic transcription and external publishing remain unconnected.
