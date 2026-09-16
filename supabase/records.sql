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
