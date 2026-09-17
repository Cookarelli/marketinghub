create or replace function private.save_campaign(p_payload jsonb) returns void
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
