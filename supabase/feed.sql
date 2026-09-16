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
