-- Validate Chicago wall time at the database boundary as well as the API.
create function private.consignment_time(wall text) returns timestamptz
language plpgsql set search_path='' as $$
declare local_time timestamp; instant timestamptz;
begin
 if wall is null or wall !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' then
  raise exception using errcode='22023',message='Choose a complete Chicago time.';
 end if;
 local_time:=wall::timestamp;
 instant:=local_time at time zone 'America/Chicago';
 if instant at time zone 'America/Chicago' <> local_time
  or (instant + interval '1 hour') at time zone 'America/Chicago' = local_time
  or (instant - interval '1 hour') at time zone 'America/Chicago' = local_time then
  raise exception using errcode='22023',message='Choose an unambiguous Chicago time outside the daylight saving gap or repeated hour.';
 end if;
 return instant;
end $$;
create function private.validate_consignment_post(d jsonb) returns void
language plpgsql set search_path='' as $$
begin
 perform private.consignment_time(d->>'date');
 if jsonb_typeof(d->'platforms') is distinct from 'array' or jsonb_typeof(d->'tasks') is distinct from 'array'
  or jsonb_typeof(d->'assets') is distinct from 'array' or jsonb_typeof(d->'references') is distinct from 'array'
  or jsonb_typeof(d->'caption') is distinct from 'string' then
  raise exception using errcode='22023',message='Check production fields.';
 end if;
 if jsonb_array_length(d->'platforms') not between 1 and 6 or jsonb_array_length(d->'tasks')>50
  or jsonb_array_length(d->'assets')>50 or jsonb_array_length(d->'references')>60 or length(d->>'caption')>10000
  or exists(select 1 from jsonb_array_elements_text(d->'platforms') where value not in ('facebook','instagram','x','youtube','tiktok','snapchat'))
  or exists(select 1 from jsonb_array_elements_text(d->'references') where value !~ '^https://' or length(value)>2000) then
  raise exception using errcode='22023',message='Check platforms, production field limits and HTTPS links.';
 end if;
end $$;
revoke all on function private.consignment_time(text),private.validate_consignment_post(jsonb) from public,anon,authenticated;

-- Campaign mutations reuse the existing staff-only record store and authorization.
-- Receipts are private and keep retries safe even after subsequent staff edits.
create table private.campaign_receipts (
 workspace_id text not null, mutation_id text not null, payload jsonb not null,
 primary key(workspace_id,mutation_id)
);
alter table private.campaign_receipts enable row level security;
revoke all on private.campaign_receipts from public,anon,authenticated;

-- Same gates apply to calendar status changes and atomic campaign saves.
create function private.assert_consignment_approval(d jsonb,c jsonb) returns void
language plpgsql set search_path='' as $$
declare v jsonb:=d->'verification'; stage text:=d->'consignment'->>'stage'; card jsonb; result jsonb;
begin
 if d->>'status' not in ('approved','published') then return; end if;
 if not exists(select 1 from jsonb_array_elements_text(d->'assets') where length(btrim(value))>0) then
  raise exception using errcode='22023',message='Add the finished creative / asset reference before approval.';
 end if;
 if exists(select 1 from jsonb_array_elements_text(d->'tasks') t where length(btrim(t.value))>0 and not coalesce(d->'completedTasks','[]'::jsonb) ? t.value) then
  raise exception using errcode='22023',message='Complete the outstanding production tasks before approval.';
 end if;
 if stage='midweek' and coalesce(length(btrim(d->>'staffPicks')),0)=0 then
  raise exception using errcode='22023',message='Record staff picks before approval.';
 end if;
 if stage not in ('closing','recap') then return; end if;
 if c is null or v->'auction' is distinct from jsonb_build_object('closing',c->'closing','batchUrl',c->'batchUrl','cards',c->'cards') then
  raise exception using errcode='22023',message='Verify the current auction facts before approval.';
 end if;
 if coalesce(length(btrim(d->>'caption')),0)=0 or v->>'reviewedCaption' is distinct from d->>'caption' or d->>'caption' ~* '\[(verify|insert)' then
  raise exception using errcode='22023',message='Review the final caption against verified facts and remove drafting placeholders.';
 end if;
 for card in select value from jsonb_array_elements(c->'cards') loop
  if not coalesce(d->'references','[]'::jsonb) ? (card->>'url') then
   raise exception using errcode='22023',message='Include every featured direct lot link before approval.';
  end if;
 end loop;
 if stage='closing' then
  if v->>'closing' is distinct from c->>'closing' or v->'lotLinksChecked' is distinct from 'true'::jsonb then
   raise exception using errcode='22023',message='Verify the closing deadline and every direct lot link before approval.';
  end if;
  if left(d->>'date',10)<>left(c->>'closing',10) or d->>'date'>c->>'closing' then
   raise exception using errcode='22023',message='Closing-day posts must be on closing day at or before the deadline.';
  end if;
 else
  if v->'resultsChecked' is distinct from 'true'::jsonb or jsonb_typeof(v->'results') is distinct from 'array' then
   raise exception using errcode='22023',message='Verify final lot results before approval.';
  end if;
  for card in select value from jsonb_array_elements(c->'cards') loop
   select value into result from jsonb_array_elements(v->'results') where value->>'url'=card->>'url';
   if result is null or coalesce(result->>'outcome','') not in ('sold','unsold','withdrawn') then
    raise exception using errcode='22023',message='Verify every featured lot as sold, unsold or withdrawn.';
   end if;
  end loop;
  if exists(select 1 from jsonb_array_elements(v->'results') r where
   (r.value ? 'price' and (r.value->>'outcome'<>'sold' or jsonb_typeof(r.value->'price')<>'number'
    or (r.value->>'price')::numeric<=0 or coalesce(r.value->>'currency','') !~ '^[A-Z]{3}$')))
   or (select count(distinct value->>'url') from jsonb_array_elements(v->'results'))<>jsonb_array_length(v->'results') then
   raise exception using errcode='22023',message='Only sold lots may have a verified sale price and currency; list each lot once.';
  end if;
  if d->>'date'<=c->>'closing' then raise exception using errcode='22023',message='Schedule the recap after closing.'; end if;
 end if;
end $$;
revoke all on function private.assert_consignment_approval(jsonb,jsonb) from public,anon,authenticated;

create function private.save_campaign(p_payload jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare
 w text:=private.require_staff(); cid text:=p_payload->>'id'; mutation text:=p_payload->>'mutationId';
 c jsonb:=p_payload->'campaign'; posts jsonb:=p_payload->'posts'; b jsonb:=p_payload->'base';
 current_campaign jsonb; current_posts jsonb; receipt jsonb; p jsonb; d jsonb; stage text;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(w,0));
 if cid is null or cid !~ '^[a-f0-9-]{36}$' or mutation is null or mutation !~ '^[a-f0-9-]{36}$'
  or jsonb_typeof(c) is distinct from 'object' or jsonb_typeof(posts) is distinct from 'array'
  or jsonb_typeof(b) is distinct from 'object' or jsonb_typeof(b->'posts') is distinct from 'array'
  or jsonb_array_length(posts) not between 5 and 100 or octet_length(p_payload::text)>1400000 then
  raise exception using errcode='22023',message='Invalid campaign payload.';
 end if;
 select payload into receipt from private.campaign_receipts where workspace_id=w and mutation_id=mutation;
 if receipt is not null then
  if receipt is distinct from p_payload then raise exception using errcode='22023',message='Retry identifier already used for different changes.'; end if;
  return;
 end if;
 if coalesce(length(c->>'name'),0) not between 1 and 500 or coalesce(c->>'batchUrl','') !~ '^https://'
  or coalesce(length(c->>'auctionPlatform'),0) not between 1 and 500
  or jsonb_typeof(c->'cards') is distinct from 'array' or jsonb_typeof(c->'platforms') is distinct from 'array'
  or coalesce(c->>'testPlatform','?') not in ('','youtube','tiktok','snapchat')
  or not exists(select 1 from private.staff_access where org_id=w and id=c->>'owner' and active) then
  raise exception using errcode='22023',message='Check campaign fields and choose an active staff member.';
 end if;
 perform private.consignment_time(c->>'opening');
 perform private.consignment_time(c->>'closing');
 perform private.consignment_time(c->>'midweek');
 perform private.consignment_time(c->>'recap');
 if jsonb_array_length(c->'cards') not between 1 and 50 or jsonb_array_length(c->'platforms') not between 1 and 6
  or exists(select 1 from jsonb_array_elements(c->'cards') where coalesce(length(value->>'name'),0) not between 1 and 500 or coalesce(value->>'url','') !~ '^https://')
  or exists(select 1 from jsonb_array_elements_text(c->'platforms') where value not in ('facebook','instagram','x','youtube','tiktok','snapchat')) then
  raise exception using errcode='22023',message='Check featured cards and primary platforms.';
 end if;
 if (c->>'closing')::timestamp <= (c->>'opening')::timestamp
  or (c->>'midweek')::timestamp < (c->>'opening')::timestamp or (c->>'midweek')::timestamp >= (c->>'closing')::timestamp
  or (c->>'recap')::timestamp <= (c->>'closing')::timestamp then
  raise exception using errcode='22023',message='Check opening, closing, midweek and recap dates.';
 end if;
 select data into current_campaign from public.marketing_records where workspace_id=w and kind='campaign' and id=cid;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'data',data) order by id),'[]'::jsonb) into current_posts
 from public.marketing_records where workspace_id=w and kind='post' and data->'consignment'->>'campaignId'=cid;
 if coalesce(current_campaign,'null'::jsonb) is distinct from b->'campaign' or current_posts is distinct from
  (select coalesce(jsonb_agg(value order by value->>'id'),'[]'::jsonb) from jsonb_array_elements(b->'posts')) then
  raise exception using errcode='40001',message='Someone edited this campaign. Reload and review again.';
 end if;
 -- No existing post may disappear from a campaign save.
 if exists(select 1 from jsonb_array_elements(current_posts) old where not exists(select 1 from jsonb_array_elements(posts) new where new->>'id'=old->>'id'))
  or (select count(distinct value->>'id') from jsonb_array_elements(posts)) <> jsonb_array_length(posts) then
  raise exception using errcode='22023',message='Include every existing campaign post exactly once.';
 end if;
 foreach stage in array array['opening','midweek','reminder','closing','recap'] loop
  if not exists(select 1 from jsonb_array_elements(posts) where value->'data'->'consignment'->>'stage'=stage) then
   raise exception using errcode='22023',message='Include all five campaign stages.';
  end if;
 end loop;
 for p in select value from jsonb_array_elements(posts) loop
  d:=p->'data';
  perform private.validate_consignment_post(d);
  -- Unchanged published records are historical; do not compare their evidence to a later auction revision.
  if not (d->>'status'='published' and exists(select 1 from jsonb_array_elements(current_posts) old where old->>'id'=p->>'id' and old->'data'=d)) then
   perform private.assert_consignment_approval(d,c);
  end if;
  if d->'consignment'->>'campaignId' is distinct from cid
   or coalesce(d->'consignment'->>'slot','') !~ '^[a-z0-9-]{1,60}$'
   or p->>'id' is distinct from 'consignment_'||cid||'_'||(d->'consignment'->>'slot')
   or coalesce(d->'consignment'->>'stage','') not in ('opening','midweek','reminder','closing','recap')
   or d->>'category' is distinct from 'Consignment' or d->>'timezone' is distinct from 'America/Chicago'
   or d ? 'recurrence' or d ? 'radarId' or d ? 'radarOrg' or d ? 'radarVersion'
   or coalesce(d->>'status','') not in ('draft','review','approved','published')
   or coalesce(d->>'date','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$'
   or coalesce(length(d->>'title'),0) not between 1 and 500
   or not exists(select 1 from private.staff_access where org_id=w and id=d->>'owner' and active) then
   raise exception using errcode='22023',message='Invalid campaign post or inactive owner.';
  end if;
  if not exists(select 1 from jsonb_array_elements(current_posts) where value->>'id'=p->>'id') and d->>'status'<>'draft' then
   raise exception using errcode='22023',message='New posts must start as drafts.';
  end if;
  if exists(select 1 from public.marketing_records where workspace_id=w and kind='post' and id=p->>'id' and data->'consignment' is distinct from d->'consignment') then
   raise exception using errcode='22023',message='Cannot replace or relabel an existing post.';
  end if;
 end loop;
 insert into public.marketing_records(workspace_id,kind,id,data) values(w,'campaign',cid,c)
 on conflict(workspace_id,kind,id) do update set data=excluded.data,updated_at=now();
 for p in select value from jsonb_array_elements(posts) loop
  insert into public.marketing_records(workspace_id,kind,id,data) values(w,'post',p->>'id',p->'data')
  on conflict(workspace_id,kind,id) do update set data=excluded.data,updated_at=now();
 end loop;
 insert into private.campaign_receipts values(w,mutation,p_payload);
end $$;
create function public.hub_save_campaign(p_payload jsonb) returns void
language sql security invoker set search_path='' as $$ select private.save_campaign(p_payload) $$;
revoke all on function private.save_campaign(jsonb),public.hub_save_campaign(jsonb) from public,anon,authenticated;
grant execute on function private.save_campaign(jsonb),public.hub_save_campaign(jsonb) to authenticated;
