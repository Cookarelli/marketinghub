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
