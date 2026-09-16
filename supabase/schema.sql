-- Reviewed schema for the Next.js/Supabase migration. Apply once to an empty project.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
create table private.staff_access (
 email text primary key check(email=lower(email)),
 org_id text not null,
 id text not null,
 name text not null,
 title text not null default '',
 role text not null check(role in ('admin','staff')),
 active boolean not null default true,
 unique(org_id,id)
);
revoke all on private.staff_access from public, anon, authenticated;
alter table private.staff_access enable row level security;
create table public.marketing_records (
 workspace_id text not null, kind text not null, id text not null,
 data jsonb not null, updated_at timestamptz not null default now(),
 primary key(workspace_id,kind,id),
 check(jsonb_typeof(data)='object' and octet_length(data::text)<1500000)
);
CREATE TABLE radar_organizations (
	id text PRIMARY KEY NOT NULL,
	name text NOT NULL
)
;
CREATE TABLE radar_sources (
	org_id text NOT NULL,
	id text NOT NULL,
	name text NOT NULL,
	url text NOT NULL,
	category text NOT NULL,
	verification text DEFAULT 'unverified' NOT NULL,
	created_at text NOT NULL,
	actor text NOT NULL,
	PRIMARY KEY(org_id, id),
	FOREIGN KEY (org_id) REFERENCES radar_organizations(id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_ingestion_runs (
	org_id text NOT NULL,
	id text NOT NULL,
	source_id text,
	status text NOT NULL,
	started_at text NOT NULL,
	finished_at text,
	error text,
	actor text NOT NULL,
	PRIMARY KEY(org_id, id),
	FOREIGN KEY (org_id) REFERENCES radar_organizations(id) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (org_id,source_id) REFERENCES radar_sources(org_id,id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_items (
	org_id text NOT NULL,
	id text NOT NULL,
	source_id text,
	run_id text,
	title text NOT NULL,
	url text NOT NULL,
	category text NOT NULL,
	kind text NOT NULL,
	priority text NOT NULL,
	status text DEFAULT 'new' NOT NULL,
	verification text DEFAULT 'unverified' NOT NULL,
	published_at text,
	collected_at text NOT NULL,
	event_date text,
	summary text DEFAULT '' NOT NULL,
	tags text DEFAULT '[]' NOT NULL,
	actor text NOT NULL,
	updated_at text NOT NULL,
	PRIMARY KEY(org_id, id),
	FOREIGN KEY (org_id) REFERENCES radar_organizations(id) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (org_id,source_id) REFERENCES radar_sources(org_id,id) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (org_id,run_id) REFERENCES radar_ingestion_runs(org_id,id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_drafts (
	org_id text NOT NULL,
	id text NOT NULL,
	item_id text NOT NULL,
	title text NOT NULL,
	body text NOT NULL,
	channel text DEFAULT 'instagram' NOT NULL,
	status text DEFAULT 'draft' NOT NULL,
	actor text NOT NULL,
	updated_at text NOT NULL,
	PRIMARY KEY(org_id, id),
	FOREIGN KEY (org_id,item_id) REFERENCES radar_items(org_id,id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_workflow_history (
	org_id text NOT NULL,
	id text NOT NULL,
	item_id text NOT NULL,
	entity text NOT NULL,
	from_status text,
	to_status text NOT NULL,
	actor text NOT NULL,
	created_at text NOT NULL,
	PRIMARY KEY(org_id, id),
	FOREIGN KEY (org_id,item_id) REFERENCES radar_items(org_id,id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_publications (
	org_id text NOT NULL,
	id text NOT NULL,
	item_id text NOT NULL,
	source_id text NOT NULL,
	external_key text NOT NULL,
	fingerprint text NOT NULL,
	original_url text NOT NULL,
	title text NOT NULL,
	excerpt text NOT NULL,
	published_at text,
	event_date text,
	observed_at text NOT NULL,
	actor text NOT NULL,
	PRIMARY KEY(org_id, id),
	FOREIGN KEY (org_id,item_id) REFERENCES radar_items(org_id,id) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (org_id,source_id) REFERENCES radar_sources(org_id,id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_editorial (
	org_id text NOT NULL,
	id text NOT NULL,
	kind text NOT NULL,
	data jsonb NOT NULL,
	version integer DEFAULT 1 NOT NULL,
	actor text NOT NULL,
	updated_at text NOT NULL,
	PRIMARY KEY(org_id, kind, id),
	FOREIGN KEY (org_id) REFERENCES radar_organizations(id) ON UPDATE no action ON DELETE no action
)
;
CREATE TABLE radar_editorial_history (
	org_id text NOT NULL,
	id text NOT NULL,
	kind text NOT NULL,
	record_id text NOT NULL,
	data jsonb NOT NULL,
	version integer NOT NULL,
	actor text NOT NULL,
	created_at text NOT NULL,
	PRIMARY KEY(org_id, id)
);
CREATE UNIQUE INDEX radar_drafts_item ON radar_drafts (org_id,item_id);
CREATE INDEX radar_history_item ON radar_workflow_history (org_id,item_id,created_at);
CREATE UNIQUE INDEX radar_items_url ON radar_items (org_id,url);
CREATE INDEX radar_items_collected ON radar_items (org_id,collected_at);
CREATE UNIQUE INDEX radar_sources_url ON radar_sources (org_id,url);
CREATE UNIQUE INDEX radar_publication_version ON radar_publications (org_id,source_id,external_key,fingerprint);
CREATE INDEX radar_publication_item ON radar_publications (org_id,item_id);
ALTER TABLE radar_items ADD canonical_url text;
ALTER TABLE radar_items ADD group_key text;
CREATE UNIQUE INDEX radar_items_canonical ON radar_items (org_id,canonical_url);
CREATE INDEX radar_items_group ON radar_items (org_id,group_key);
ALTER TABLE radar_ingestion_runs ADD fetched integer DEFAULT 0 NOT NULL;
ALTER TABLE radar_ingestion_runs ADD added integer DEFAULT 0 NOT NULL;
ALTER TABLE radar_ingestion_runs ADD duplicates integer DEFAULT 0 NOT NULL;
ALTER TABLE radar_ingestion_runs ADD updates integer DEFAULT 0 NOT NULL;
ALTER TABLE radar_ingestion_runs ADD error_code text;
ALTER TABLE radar_sources ADD seed_key text;
ALTER TABLE radar_sources ADD method text DEFAULT 'manual' NOT NULL;
ALTER TABLE radar_sources ADD connection_status text DEFAULT 'manual' NOT NULL;
ALTER TABLE radar_sources ADD priority text DEFAULT 'normal' NOT NULL;
ALTER TABLE radar_sources ADD enabled integer DEFAULT 1 NOT NULL;
ALTER TABLE radar_sources ADD feed_url text;
ALTER TABLE radar_sources ADD last_attempt text;
ALTER TABLE radar_sources ADD last_success text;
ALTER TABLE radar_sources ADD last_error text;
ALTER TABLE radar_sources ADD error_code text;
ALTER TABLE radar_sources ADD next_attempt text;
ALTER TABLE radar_sources ADD etag text;
ALTER TABLE radar_sources ADD modified text;
ALTER TABLE radar_sources ADD cursor text;
ALTER TABLE radar_sources ADD config_version integer DEFAULT 0 NOT NULL;
ALTER TABLE radar_sources ADD lock_token text;
ALTER TABLE radar_sources ADD lock_until text;
CREATE UNIQUE INDEX radar_sources_seed ON radar_sources (org_id,seed_key);

insert into public.radar_organizations values ('northside-marketing','Northside Collectibles');
alter table public.radar_items add check(kind in ('story','release','chase'));
alter table public.radar_items add check(status in ('new','saved','dismissed'));
alter table public.radar_items add check(verification in ('unverified','verified','disputed'));
alter table public.radar_items add check(priority in ('normal','high','urgent'));
alter table public.radar_items add check(length(title) between 1 and 300 and length(summary)<=4000 and length(url)<=2048);
alter table public.radar_sources add check(enabled in (0,1));
alter table public.radar_sources add check(method in ('manual','discover','rss','atom','page'));
alter table public.radar_drafts add check(status in ('draft','review','approved'));
alter table public.radar_editorial add check(kind in ('product','detail','queue','team','collection-job'));
alter table public.radar_editorial add check(jsonb_typeof(data)='object' and octet_length(data::text)<30000);
create index radar_runs_source on public.radar_ingestion_runs(org_id,source_id,started_at desc);
create index radar_items_source on public.radar_items(org_id,source_id);
create index radar_items_run on public.radar_items(org_id,run_id);
create index radar_editorial_recent on public.radar_editorial(org_id,updated_at desc);
create index radar_editorial_history_recent on public.radar_editorial_history(org_id,created_at desc);

-- Access always uses Auth's verified email and a current private roster row.
-- Neither editable user_metadata nor a stale JWT role grants workspace access.
create function private.workspace() returns text language sql stable security definer set search_path='' as $$
 select a.org_id from private.staff_access a join auth.users u on lower(u.email)=a.email
 where u.id=(select auth.uid()) and u.email_confirmed_at is not null and a.active
$$;
create function private.staff_role() returns text language sql stable security definer set search_path='' as $$
 select a.role from private.staff_access a join auth.users u on lower(u.email)=a.email
 where u.id=(select auth.uid()) and u.email_confirmed_at is not null and a.active
$$;
create function private.require_staff() returns text language plpgsql security definer set search_path='' as $$
declare workspace text;
begin
 select a.org_id into workspace from private.staff_access a join auth.users u on lower(u.email)=a.email
 where u.id=(select auth.uid()) and u.email_confirmed_at is not null and a.active for share of a;
 if workspace is null then raise exception using errcode='42501',message='Staff access required.'; end if;
 return workspace;
end $$;
create function public.hub_context() returns jsonb language sql security invoker set search_path='' as $$
 select jsonb_build_object('orgId',private.workspace(),'userId',auth.uid(),'orgName','Northside Collectibles','role',private.staff_role())
$$;
alter table public.marketing_records enable row level security;
revoke all on public.marketing_records from public,anon,authenticated;
grant select on public.marketing_records to authenticated;
create policy staff_read on public.marketing_records for select to authenticated using (workspace_id=(select private.workspace()));
alter table public.radar_organizations enable row level security;
revoke all on public.radar_organizations from public,anon,authenticated;
grant select on public.radar_organizations to authenticated;
create policy staff_read on public.radar_organizations for select to authenticated using (id=(select private.workspace()));
alter table public.radar_sources enable row level security;
revoke all on public.radar_sources from public,anon,authenticated;
grant select on public.radar_sources to authenticated;
create policy staff_read on public.radar_sources for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_ingestion_runs enable row level security;
revoke all on public.radar_ingestion_runs from public,anon,authenticated;
grant select on public.radar_ingestion_runs to authenticated;
create policy staff_read on public.radar_ingestion_runs for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_items enable row level security;
revoke all on public.radar_items from public,anon,authenticated;
grant select on public.radar_items to authenticated;
create policy staff_read on public.radar_items for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_drafts enable row level security;
revoke all on public.radar_drafts from public,anon,authenticated;
grant select on public.radar_drafts to authenticated;
create policy staff_read on public.radar_drafts for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_workflow_history enable row level security;
revoke all on public.radar_workflow_history from public,anon,authenticated;
grant select on public.radar_workflow_history to authenticated;
create policy staff_read on public.radar_workflow_history for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_publications enable row level security;
revoke all on public.radar_publications from public,anon,authenticated;
grant select on public.radar_publications to authenticated;
create policy staff_read on public.radar_publications for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_editorial enable row level security;
revoke all on public.radar_editorial from public,anon,authenticated;
grant select on public.radar_editorial to authenticated;
create policy staff_read on public.radar_editorial for select to authenticated using (org_id=(select private.workspace()));
alter table public.radar_editorial_history enable row level security;
revoke all on public.radar_editorial_history from public,anon,authenticated;
grant select on public.radar_editorial_history to authenticated;
create policy staff_read on public.radar_editorial_history for select to authenticated using (org_id=(select private.workspace()));
