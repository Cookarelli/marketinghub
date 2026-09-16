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


create function private.save_record(p_kind text,p_id text,p_data jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare w text:=private.require_staff(); pending jsonb;
begin
 if p_kind not in ('plan','post','link','metrics','clipjob','upload','asset') or length(p_id) not between 1 and 180 then
  raise exception using errcode='22023',message='Invalid record.';
 end if;
 if p_kind='post' and (left(p_id,6)='radar_' or p_data ? 'radarId' or p_data ? 'radarOrg' or p_data ? 'radarVersion') then
  raise exception using errcode='42501',message='Edit Radar posts through the editorial review queue.';
 end if;
 if p_kind='upload' then
  if p_data->>'key' is distinct from w||'/'||p_id or (p_data->>'size')::bigint not between 1 and 41943040
   or p_data->>'type' not in ('image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm') then
   raise exception using errcode='22023',message='Invalid upload.';
  end if;
 end if;
 if p_kind='asset' then
  select data into pending from public.marketing_records where workspace_id=w and kind='upload' and id=p_id;
  if pending is null or pending is distinct from p_data or not exists (
   select 1 from storage.objects where bucket_id='marketing-assets' and name=pending->>'key'
    and (metadata->>'size')::bigint=(pending->>'size')::bigint and metadata->>'mimetype'=pending->>'type'
  ) then raise exception using errcode='22023',message='Upload must finish before saving the asset.'; end if;
 end if;
 insert into public.marketing_records(workspace_id,kind,id,data) values(w,p_kind,p_id,p_data)
 on conflict(workspace_id,kind,id) do update set data=excluded.data,updated_at=now();
end $$;
create function public.hub_save_record(p_kind text,p_id text,p_data jsonb) returns void
language sql security invoker set search_path='' as $$ select private.save_record(p_kind,p_id,p_data) $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('marketing-assets','marketing-assets',false,41943040,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm']);
create policy hub_asset_read on storage.objects for select to authenticated
using(bucket_id='marketing-assets' and split_part(name,'/',1)=(select private.workspace()));
create policy hub_asset_upload on storage.objects for insert to authenticated
with check(bucket_id='marketing-assets' and split_part(name,'/',1)=(select private.workspace()) and array_length(string_to_array(name,'/'),1)=2);


-- All writes are named operations. They derive workspace and actor from Auth,
-- take a current membership lock, and commit together in one transaction.
create function private.radar(p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 w text:=private.require_staff(); actor_id text:=auth.uid()::text;
 stamp text:=to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
 ident text:=coalesce(p_data->>'id',gen_random_uuid()::text);
 d jsonb:=p_data->'data'; src public.radar_sources; story public.radar_items;
 run_id text; token text; entry jsonb; seed jsonb; v_item_id text; prior record;
 changed boolean;
 added integer:=0; duplicates integer:=0; updates integer:=0; affected integer;
begin
 if octet_length(p_data::text)>250000 then raise exception using errcode='22023',message='Request too large.'; end if;
 case p_action
 when 'add-source' then
  insert into public.radar_sources(org_id,id,name,url,category,created_at,actor)
  values(w,ident,d->>'name',d->>'url',d->>'category',stamp,actor_id);
 when 'add-item' then
  run_id:=gen_random_uuid()::text;
  insert into public.radar_ingestion_runs(org_id,id,source_id,status,started_at,finished_at,actor)
  values(w,run_id,d->>'sourceId','manual',stamp,stamp,actor_id);
  insert into public.radar_items(org_id,id,source_id,run_id,title,url,category,kind,priority,published_at,collected_at,event_date,summary,tags,actor,updated_at)
  values(w,ident,d->>'sourceId',run_id,d->>'title',d->>'url',d->>'category',d->>'kind',d->>'priority',d->>'publishedAt',stamp,d->>'eventDate',d->>'summary',(d->'tags')::text,actor_id,stamp);
 when 'save-idea' then
  select * into story from public.radar_items where org_id=w and id=ident for update;
  if not found then raise exception using errcode='P0002',message='Story unavailable.'; end if;
  insert into public.radar_drafts(org_id,id,item_id,title,body,channel,status,actor,updated_at)
  values(w,gen_random_uuid()::text,ident,story.title,'Northside content idea: '||story.title||E'\n\nSource: '||story.url,'instagram','draft',actor_id,stamp)
  on conflict(org_id,item_id) do nothing;
  insert into public.radar_editorial(org_id,id,kind,data,actor,updated_at)
  values(w,ident,'queue',p_data->'blankQueue'||jsonb_build_object('state','Saved','itemId',ident,'title',story.title,'instagram','Northside content idea: '||story.title||E'\n\nSource: '||story.url,'references',jsonb_build_array(story.url)),actor_id,stamp)
  on conflict(org_id,kind,id) do nothing;
  update public.radar_items set status='saved',actor=actor_id,updated_at=stamp where org_id=w and id=ident;
 when 'set-status','verify' then
  update public.radar_items set status=case when p_action='set-status' then p_data->>'status' else status end,
   verification=case when p_action='verify' then p_data->>'verification' else verification end,actor=actor_id,updated_at=stamp where org_id=w and id=ident;
  if not found then raise exception using errcode='P0002',message='Story unavailable.'; end if;
 when 'edit-draft' then
  if p_data->>'status'='approved' then raise exception using errcode='22023',message='Approve through the editorial queue.'; end if;
  if exists(select 1 from public.radar_drafts dr join public.radar_editorial e on e.org_id=dr.org_id and e.id=dr.item_id and e.kind='queue' where dr.org_id=w and dr.id=ident) then
   raise exception using errcode='40001',message='Edit this draft in the editorial queue.';
  end if;
  update public.radar_drafts set title=p_data->>'title',body=p_data->>'body',channel=p_data->>'channel',status=p_data->>'status',actor=actor_id,updated_at=stamp where org_id=w and id=ident;
  if not found then raise exception using errcode='P0002',message='Draft unavailable.'; end if;
 when 'seed-sources' then
  for seed in select value from jsonb_array_elements(p_data->'sources') loop
   update public.radar_sources set seed_key=seed->>'key' where org_id=w and url=seed->>'url' and seed_key is null
   and not exists(select 1 from public.radar_sources where org_id=w and seed_key=seed->>'key');
   insert into public.radar_sources(org_id,id,name,url,category,created_at,actor,seed_key,method,connection_status,priority,feed_url)
   values(w,gen_random_uuid()::text,seed->>'name',seed->>'url',seed->>'category',stamp,actor_id,seed->>'key',
    case when coalesce((seed->>'social')::boolean,false) then 'manual' else 'discover' end,
    case when coalesce((seed->>'social')::boolean,false) then 'manual' else 'pending' end,seed->>'priority',seed->>'feed') on conflict do nothing;
  end loop;
 when 'edit-source' then
  select * into src from public.radar_sources where org_id=w and id=ident for update;
  if not found then raise exception using errcode='P0002',message='Source unavailable.'; end if;
  changed:=d->>'url' is distinct from src.url or (d->>'mode'='manual') is distinct from (src.method='manual');
  update public.radar_sources set name=d->>'name',url=d->>'url',category=d->>'category',priority=d->>'priority',enabled=case when (d->>'enabled')::boolean then 1 else 0 end,
   method=case when changed then d->>'mode' else method end,connection_status=case when not changed then connection_status when d->>'mode'='manual' then 'manual' else 'pending' end,
   feed_url=case when changed then null else feed_url end,etag=case when changed then null else etag end,modified=case when changed then null else modified end,cursor=case when changed then null else cursor end,last_error=null,error_code=null,next_attempt=null,
   config_version=config_version+1,lock_token=null,lock_until=null,actor=actor_id where org_id=w and id=ident;
 when 'acquire-source' then
  select * into src from public.radar_sources where org_id=w and enabled=1 and method!='manual'
   and (next_attempt is null or next_attempt<=stamp) and (lock_until is null or lock_until<stamp)
   and (p_data->>'id' is null or id=p_data->>'id')
   order by last_attempt is not null,last_attempt,case priority when 'urgent' then 0 when 'high' then 1 else 2 end
   limit 1 for update skip locked;
  if not found then return 'null'::jsonb; end if;
  token:=gen_random_uuid()::text; run_id:=gen_random_uuid()::text;
  update public.radar_sources set lock_token=token,lock_until=to_char((now()+interval '90 seconds') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),last_attempt=stamp,actor=actor_id where org_id=w and id=src.id;
  update public.radar_ingestion_runs set status='interrupted',finished_at=stamp,error='Collection was interrupted. Retrying.',error_code='interrupted',actor=actor_id
   where org_id=w and source_id=src.id and status='running';
  insert into public.radar_ingestion_runs(org_id,id,source_id,status,started_at,actor) values(w,run_id,src.id,'running',stamp,actor_id);
  return jsonb_build_object('source',to_jsonb(src),'token',token,'runId',run_id);
 when 'ingest-entries' then
  select * into src from public.radar_sources where org_id=w and id=p_data->>'sourceId' and lock_token=p_data->>'token'
   and config_version=(p_data->>'version')::integer and enabled=1 for update;
  if not found then raise exception using errcode='40001',message='Source settings changed during collection.'; end if;
  if jsonb_array_length(p_data->'entries')>20 then raise exception using errcode='22023',message='Collection batch too large.'; end if;
  for entry in select value from jsonb_array_elements(p_data->'entries') loop
   select p.item_id,p.fingerprint into prior from public.radar_publications p where p.org_id=w and p.source_id=src.id and p.external_key=entry->>'key' order by observed_at desc limit 1;
   if prior.fingerprint=entry->>'fingerprint' then duplicates:=duplicates+1; continue; end if;
   v_item_id:=prior.item_id;
   if v_item_id is null then select id into v_item_id from public.radar_items where org_id=w and (url=entry->>'url' or canonical_url=entry->>'url' or group_key=entry->>'group') limit 1; end if;
   if v_item_id is null then
    v_item_id:=gen_random_uuid()::text;
    insert into public.radar_items(org_id,id,source_id,run_id,title,url,canonical_url,group_key,category,kind,priority,published_at,collected_at,event_date,summary,tags,actor,updated_at)
    values(w,v_item_id,src.id,p_data->>'runId',entry->>'title',entry->>'url',entry->>'url',entry->>'group',src.category,entry->>'kind',src.priority,entry->>'publishedAt',stamp,entry->>'eventDate',entry->>'summary','[]',actor_id,stamp)
    on conflict do nothing;
    get diagnostics affected=row_count;
    select id into v_item_id from public.radar_items where org_id=w and (id=v_item_id or canonical_url=entry->>'url') limit 1;
    added:=added+affected;
   else updates:=updates+1;
   end if;
   insert into public.radar_publications(org_id,id,item_id,source_id,external_key,fingerprint,original_url,title,excerpt,published_at,event_date,observed_at,actor)
   values(w,gen_random_uuid()::text,v_item_id,src.id,entry->>'key',entry->>'fingerprint',entry->>'originalUrl',entry->>'title',entry->>'summary',entry->>'publishedAt',entry->>'eventDate',stamp,actor_id) on conflict do nothing;
  end loop;
  return jsonb_build_object('added',added,'duplicates',duplicates,'updates',updates);
 when 'finish-source' then
  select * into src from public.radar_sources where org_id=w and id=p_data->>'sourceId' and lock_token=p_data->>'token' and config_version=(p_data->>'version')::integer for update;
  if not found then return jsonb_build_object('ok',true,'stale',true); end if;
  update public.radar_ingestion_runs set status=d->>'status',finished_at=stamp,error=d->>'error',error_code=d->>'code',
   fetched=coalesce((d->>'fetched')::integer,0),added=coalesce((d->>'added')::integer,0),duplicates=coalesce((d->>'duplicates')::integer,0),updates=coalesce((d->>'updates')::integer,0),actor=actor_id
   where org_id=w and id=p_data->>'runId' and source_id=src.id;
  update public.radar_sources set method=coalesce(d->>'method',method),feed_url=coalesce(d->>'feedUrl',feed_url),
   connection_status=case when d->>'status' in ('success','unchanged') then 'connected' when d->>'code'='blocked' then 'blocked' else 'error' end,
   last_success=case when d->>'status' in ('success','unchanged') then stamp else last_success end,last_error=d->>'error',error_code=d->>'code',
   next_attempt=to_char((now()+make_interval(secs=>greatest(2,least(86400,coalesce((d->>'retryAfter')::integer,300))))) at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
   etag=case when d->>'status' in ('success','unchanged') then d->>'etag' else etag end,
   modified=case when d->>'status' in ('success','unchanged') then d->>'modified' else modified end,
   cursor=case when d->>'status' in ('success','unchanged') then d->>'cursor' else cursor end,lock_token=null,lock_until=null,actor=actor_id
   where org_id=w and id=src.id;
 else raise exception using errcode='22023',message='Unknown Radar operation.';
 end case;
 return jsonb_build_object('ok',true,'id',ident);
end $$;
create function public.hub_radar(p_action text,p_data jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select private.radar(p_action,p_data) $$;


create function public.hub_radar_feed(p_filters jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$
 with filtered as (
  select i.* from public.radar_items i
  left join public.radar_drafts d on d.org_id=i.org_id and d.item_id=i.id
  where i.org_id=(select private.workspace())
   and (p_filters->>'tab'!='releases' or i.kind='release')
   and (p_filters->>'tab'!='chase' or i.kind='chase')
   and (p_filters->>'tab'!='drafts' or d.id is not null)
   and (coalesce(p_filters->>'q','')='' or position(lower(p_filters->>'q') in lower(concat_ws(' ',i.title,i.summary,i.tags,d.body,d.title)))>0)
   and (p_filters->>'category'='all' or i.category=p_filters->>'category')
   and (p_filters->>'priority'='all' or i.priority=p_filters->>'priority')
   and (p_filters->>'source'='all' or (p_filters->>'source'='manual' and i.source_id is null)
    or i.source_id=p_filters->>'source' or exists(select 1 from public.radar_publications p where p.org_id=i.org_id and p.item_id=i.id and p.source_id=p_filters->>'source'))
   and (p_filters->>'status'='all' or i.status=p_filters->>'status' or d.status=p_filters->>'status')
   and (p_filters->>'after'='' or left(coalesce(i.published_at,i.collected_at),10)>=p_filters->>'after')
   and (p_filters->>'before'='' or left(coalesce(i.published_at,i.collected_at),10)<=p_filters->>'before')
 ), page as (
  select * from filtered order by case priority when 'urgent' then 0 when 'high' then 1 else 2 end,collected_at desc,id
  limit 50 offset greatest(0,least(1000000,coalesce((p_filters->>'offset')::integer,0)))
 ) select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(page)) from page),'[]'::jsonb),'total',(select count(*) from filtered))
$$;

create function private.workflow_history() returns trigger language plpgsql security definer set search_path='' as $$
declare story_id text; entity_name text; before_state text; after_state text;
begin
 if tg_table_name='radar_drafts' then story_id:=new.item_id;entity_name:='draft';else story_id:=new.id;entity_name:='item';end if;
 if tg_op='INSERT' then before_state:=null;else before_state:=old.status;end if;
 after_state:=new.status;
 if before_state is distinct from after_state then
  insert into public.radar_workflow_history(org_id,id,item_id,entity,from_status,to_status,actor,created_at)
  values(new.org_id,gen_random_uuid()::text,story_id,entity_name,before_state,after_state,new.actor,new.updated_at);
 end if;
 if tg_table_name='radar_items' and tg_op='UPDATE' then
 if old.verification is distinct from new.verification then
  insert into public.radar_workflow_history(org_id,id,item_id,entity,from_status,to_status,actor,created_at)
  values(new.org_id,gen_random_uuid()::text,new.id,'verification',old.verification,new.verification,new.actor,new.updated_at);
 end if;
 end if;
 return new;
end $$;
create trigger item_history after insert or update on public.radar_items for each row execute function private.workflow_history();
create trigger draft_history after insert or update on public.radar_drafts for each row execute function private.workflow_history();


alter table private.staff_access add column version integer not null default 1;

create function private.team() returns jsonb language plpgsql security definer set search_path='' as $$
declare w text:=private.require_staff(); result jsonb;
begin
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'kind','team','version',a.version,'updated_at',now(),
  'data',jsonb_build_object('name',a.name,'email',a.email,'title',a.title,'role',a.role,'active',a.active,'userId',coalesce(u.id::text,'')))),'[]'::jsonb)
 into result from private.staff_access a left join auth.users u on lower(u.email)=a.email and u.email_confirmed_at is not null where a.org_id=w;
 return result;
end $$;
create function public.hub_team() returns jsonb language sql security invoker set search_path='' as $$ select private.team() $$;

create function private.editorial_history() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.radar_editorial_history(org_id,id,kind,record_id,data,version,actor,created_at)
 values(new.org_id,gen_random_uuid()::text,new.kind,new.id,new.data,new.version,new.actor,new.updated_at);
 if new.kind='queue' then
  update public.marketing_records set data=jsonb_set(data,'{status}','"review"'::jsonb),updated_at=now()
  where workspace_id=new.org_id and kind='post' and data->>'radarId'=new.id;
 end if;
 return new;
end $$;
create trigger editorial_history after insert or update on public.radar_editorial for each row execute function private.editorial_history();

create function private.editorial_save(p_kind text,p_id text,p_version integer,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w text:=private.require_staff(); actor_id text:=auth.uid()::text;
 oldrow public.radar_editorial; old_team private.staff_access; d jsonb:=p_data;
 stamp text:=to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
begin
 -- Serialize editorial changes and calendar copies within this workspace.
 -- Product/fact edits cannot race an approval or leave its calendar copy approved.
 perform pg_advisory_xact_lock(hashtextextended(w,0));
 if p_kind is null or p_id is null or p_version is null or p_kind not in ('product','detail','queue','team') or length(p_id) not between 1 and 100 or p_version<0
  or jsonb_typeof(d) is distinct from 'object' or octet_length(d::text)>30000 then
  raise exception using errcode='22023',message='Invalid editorial request.';
 end if;
 if p_kind='team' then
  if private.staff_role()!='admin' then raise exception using errcode='42501',message='Only administrators can manage access.'; end if;
  select * into old_team from private.staff_access where org_id=w and id=p_id for update;
  if not found then raise exception using errcode='P0002',message='Staff member unavailable.'; end if;
  if old_team.version!=p_version then raise exception using errcode='40001',message='Someone edited this record. Reload before saving.'; end if;
  if old_team.email=(select lower(email) from auth.users where id=auth.uid()) and
   (d->>'role' is distinct from 'admin' or (d->>'active')::boolean is distinct from true or lower(d->>'email') is distinct from old_team.email) then
   raise exception using errcode='22023',message='You cannot revoke or replace your own administrator login.';
  end if;
  if coalesce(d->>'email','')!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or coalesce(d->>'role','') not in ('admin','staff') then
   raise exception using errcode='22023',message='A valid staff email and role are required.';
  end if;
  update private.staff_access set name=d->>'name',title=d->>'title',email=lower(d->>'email'),role=d->>'role',active=(d->>'active')::boolean,version=version+1 where org_id=w and id=p_id;
  insert into public.radar_editorial_history(org_id,id,kind,record_id,data,version,actor,created_at)
  values(w,gen_random_uuid()::text,'team',p_id,d,p_version+1,actor_id,stamp);
  return jsonb_build_object('ok',true,'data',d);
 end if;
 select * into oldrow from public.radar_editorial where org_id=w and kind=p_kind and id=p_id for update;
 if coalesce(oldrow.version,0)!=p_version then raise exception using errcode='40001',message='Someone edited this record. Reload before saving.'; end if;
 if p_kind='product' then
  if d->>'status' in ('carried','incoming') and exists(select 1 from unnest(array['year','set','sport','format','evidence','confirmedAt']) k where coalesce(d->>k,'')='') then
   raise exception using errcode='22023',message='Confirmed inventory needs exact product details and dated evidence.';
  end if;
 end if;
 if p_kind='detail' then
  if not exists(select 1 from public.radar_items where org_id=w and id=p_id) then raise exception using errcode='P0002',message='Story unavailable.'; end if;
  if (coalesce(d->>'manufacturerDate','')!='' and coalesce(d->>'manufacturerSource','')='') or
   (coalesce(d->>'arrivalDate','')!='' and coalesce(d->>'arrivalSource','')='') or
   (d->>'certainty'='confirmed' and coalesce(d->>'evidence','')='') or
   (d->>'pullStatus'!='unknown' and (coalesce(d->>'pullEvidence','')='' or coalesce(d->>'pullAsOf','')='')) then
   raise exception using errcode='22023',message='Confirmed facts need dated source evidence.';
  end if;
 end if;
 if p_kind='queue' then
  if coalesce(d->>'state','') not in ('Saved','Draft','Needs review','Approved','Archived') or coalesce(d->>'title','')='' then raise exception using errcode='22023',message='A title and editorial state are required.'; end if;
  if coalesce(oldrow.data->>'itemId','')!='' and oldrow.data->>'itemId' is distinct from d->>'itemId' then raise exception using errcode='22023',message='The source story cannot be reassigned.'; end if;
  if coalesce(d->>'itemId','')!='' and not exists(select 1 from public.radar_items where org_id=w and id=d->>'itemId') then raise exception using errcode='P0002',message='Story unavailable.'; end if;
  if coalesce(d->>'assignee','')!='' and not exists(select 1 from private.staff_access where org_id=w and id=d->>'assignee') then raise exception using errcode='22023',message='Choose a member of this team.'; end if;
  if coalesce(d->>'assetId','')!='' then
   if not exists(select 1 from public.marketing_records where workspace_id=w and kind='asset' and id=d->>'assetId') then raise exception using errcode='22023',message='Upload this asset in Content studio first.'; end if;
   d:=jsonb_set(d,'{assetOwner}',to_jsonb(w));
  else d:=jsonb_set(d,'{assetOwner}','""'::jsonb); end if;
  if oldrow.data->>'state'='Approved' and (oldrow.data-array['state','notes','assignee']) is distinct from (d-array['state','notes','assignee']) then d:=jsonb_set(d,'{state}','"Needs review"'::jsonb); end if;
  if d->>'state'='Approved' and oldrow.data->>'state' is distinct from 'Approved' then
   if private.staff_role()!='admin' then raise exception using errcode='42501',message='An administrator must approve the draft.'; end if;
   if oldrow.data->>'state' is distinct from 'Needs review' or (oldrow.data-array['state','notes','assignee']) is distinct from (d-array['state','notes','assignee']) then raise exception using errcode='22023',message='Save the final edits in Needs review before approving.'; end if;
   if exists(select 1 from unnest(array['facebook','instagram','reel','cta']) k where btrim(coalesce(d->>k,''))='') then raise exception using errcode='22023',message='Complete both captions, the Reel outline and call to action.'; end if;
   if coalesce(jsonb_array_length(d->'references'),0)=0 and coalesce(d->>'original','none')='none' then raise exception using errcode='22023',message='Add source references.'; end if;
   if (coalesce(d->>'assetId','')!='' or coalesce(d->>'original','none')!='none') and
    (coalesce(d->>'permission','') not in ('owned','granted') or btrim(coalesce(d->>'attribution',''))='' or btrim(coalesce(d->>'permissionEvidence',''))='') then
    raise exception using errcode='22023',message='Record attribution and reuse permission before approval.';
   end if;
  end if;
 end if;
 insert into public.radar_editorial(org_id,kind,id,data,version,actor,updated_at) values(w,p_kind,p_id,d,p_version+1,actor_id,stamp)
 on conflict(org_id,kind,id) do update set data=excluded.data,version=excluded.version,actor=excluded.actor,updated_at=excluded.updated_at;
 if p_kind in ('product','detail') then
  update public.radar_editorial set data=jsonb_set(data,'{state}','"Needs review"'::jsonb),version=version+1,actor=actor_id,updated_at=stamp
   where org_id=w and kind='queue' and data->>'state'='Approved' and (p_kind='product' or data->>'itemId'=p_id);
 end if;
 if p_kind='queue' then
  update public.radar_drafts set title=d->>'title',body=coalesce(nullif(d->>'instagram',''),d->>'facebook',''),
   status=case d->>'state' when 'Approved' then 'approved' when 'Needs review' then 'review' else 'draft' end,actor=actor_id,updated_at=stamp where org_id=w and item_id=d->>'itemId';
 end if;
 return jsonb_build_object('ok',true,'data',d);
end $$;
create function public.hub_editorial_save(p_kind text,p_id text,p_version integer,p_data jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select private.editorial_save(p_kind,p_id,p_version,p_data) $$;

create function private.calendar(p_id text) returns jsonb language plpgsql security definer set search_path='' as $$
declare w text:=private.require_staff(); draft public.radar_editorial; d jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended(w,0));
 select * into draft from public.radar_editorial where org_id=w and kind='queue' and id=p_id for share;
 if not found then raise exception using errcode='P0002',message='Draft unavailable.'; end if;
 if draft.data->>'state' is distinct from 'Approved' or coalesce(draft.data->>'calendarDate','')='' then raise exception using errcode='22023',message='Approve the draft and choose a calendar date first.'; end if;
 d:=jsonb_build_object('title',draft.data->>'title','date',draft.data->>'calendarDate','timezone','America/Chicago','source',draft.data->>'calendarChannel',
  'caption',(case when draft.data->>'calendarChannel'='facebook' then draft.data->>'facebook' else draft.data->>'instagram' end)||E'\n\n'||(draft.data->>'cta'),
  'status','approved','radarOrg',w,'radarId',p_id,'radarVersion',draft.version);
 insert into public.marketing_records(workspace_id,kind,id,data) values(w,'post','radar_'||p_id,d)
 on conflict(workspace_id,kind,id) do update set data=excluded.data,updated_at=now();
 return jsonb_build_object('ok',true);
end $$;
create function public.hub_calendar(p_id text) returns jsonb language sql security invoker set search_path='' as $$ select private.calendar(p_id) $$;


-- Supabase grants function EXECUTE to PUBLIC by default. Close that default.
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.workspace(),private.staff_role(),private.require_staff(),private.save_record(text,text,jsonb),
 private.radar(text,jsonb),private.team(),private.editorial_save(text,text,integer,jsonb),private.calendar(text) to authenticated;
revoke all on function public.hub_context(),public.hub_save_record(text,text,jsonb),public.hub_radar(text,jsonb),
 public.hub_radar_feed(jsonb),public.hub_team(),public.hub_editorial_save(text,text,integer,jsonb),public.hub_calendar(text) from public,anon,authenticated;
grant execute on function public.hub_context(),public.hub_save_record(text,text,jsonb),public.hub_radar(text,jsonb),
 public.hub_radar_feed(jsonb),public.hub_team(),public.hub_editorial_save(text,text,integer,jsonb),public.hub_calendar(text) to authenticated;
