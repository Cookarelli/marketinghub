# Consignment campaigns

In Calendar, select **Add consignment campaign**, enter the batch and featured lot details, select an active staff member and social platforms, and choose opening, closing, midweek and recap times. Optional tests are YouTube, TikTok or Snapchat. Preview the five stages, adjust posts and production fields, and save. Each generated post starts as a draft; publishing is manual.

All wall-clock inputs and exports are America/Chicago. The 48-hour reminder uses elapsed time, not two calendar days. DST gaps and repeated hours are rejected with an explanation; choose an unambiguous time. The preview warns about exact-time collisions, days exceeding three calendar entries (including Tuesday series), reminders before opening, and adjusted reminders no longer 48 hours before closing. Platform variants within one calendar entry count as one post, matching the existing calendar. Warnings never move existing entries.

Use **Edit / reschedule** on a saved campaign to change dates. Update the preview to see affected old and new dates. Post captions, tasks, asset references, links, owners, platforms, completed tasks, staff picks, entered results, added spotlights and manual offsets from stage times are preserved. Campaign metadata changes do not overwrite staff-authored post fields; review those fields for changed auction facts. Closing-time and result verification are explicit staff attestations. Changed auction facts clear their confirmations and return approved closing/recap posts to review; entered results and completed production work remain. Published posts retain their historical dates and content.

Campaigns are stored as `campaign` records. Posts retain optional `consignment` identity metadata, plus owner, platforms, tasks and asset references. Calendar CSV includes these fields and campaign details; the existing workspace export includes both records. Asset references can use Content studio IDs. Storage remains private and uses the existing asset flow.

## Approval safeguards

Every campaign post must have a finished asset reference and completed production tasks before approval or manually marking it published. Midweek posts also require staff picks. Closing-day posts require the current exact Chicago closing deadline, verified direct lot links, and a final caption checked against those facts. Recaps require an explicit sold/unsold/withdrawn outcome for each featured lot, a results confirmation, and reviewed final copy. Prices are optional and may only be recorded for sold lots with a currency. The recap helper never estimates prices or treats unsold lots as sold.

The UI lists missing production work and disables approval until it is complete. PostgreSQL enforces the same rules through both the generic record RPC and campaign RPC. Verification is bound to the campaign facts and exact caption. Changing a caption or deadline cannot retain stale approval. These controls document human review; the app does not independently verify auction websites or publish posts.

## Deployment

Apply `supabase/migrations/20260917180437_consignment_campaigns.sql`, then `supabase/migrations/20260917180743_consignment_preserve_published_history.sql`, to the existing initialized Supabase database before deploying this UI. The migration creates private retry receipts and the staff-authorized `hub_save_campaign` RPC, and updates `private.save_record` to protect campaign membership. It does not modify existing calendar data or Tuesday seed entries. `supabase/consignment.sql` is the readable SQL module; the migration also includes the updated existing record function.

Keep the existing `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` configuration. No new key or public table access is needed. Staff assignments come from the existing active private roster. Do not add real auction data, staff names, emails, credentials, or exports to source control. Tests use fictional batches and `example.test` URLs.

Saving a campaign is one transaction. Stable post IDs and private mutation receipts prevent duplicate retries, even if someone subsequently edits a post. The transaction compares the complete original campaign/post snapshot and rejects stale updates instead of overwriting staff work. Ordinary post edits share the same workspace lock. Campaign membership cannot be changed through the generic record endpoint.

## Verification

`pnpm test` covers both DST transitions, invalid and ambiguous times, short auctions, Tuesday collisions, capacity warnings, preserving edits and spotlights, API validation, actual PostgreSQL migration execution, authorization, rollback, retry receipts and stale writes. Run `pnpm typecheck`, `pnpm lint`, and `pnpm build` as well. An authenticated deployed smoke test still requires configured Supabase and a verified staff account.
