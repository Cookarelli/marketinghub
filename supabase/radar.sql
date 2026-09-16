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
