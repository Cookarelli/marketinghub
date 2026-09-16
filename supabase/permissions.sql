-- Supabase grants function EXECUTE to PUBLIC by default. Close that default.
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.workspace(),private.staff_role(),private.require_staff(),private.save_record(text,text,jsonb),
 private.radar(text,jsonb),private.team(),private.editorial_save(text,text,integer,jsonb),private.calendar(text) to authenticated;
revoke all on function public.hub_context(),public.hub_save_record(text,text,jsonb),public.hub_radar(text,jsonb),
 public.hub_radar_feed(jsonb),public.hub_team(),public.hub_editorial_save(text,text,integer,jsonb),public.hub_calendar(text) from public,anon,authenticated;
grant execute on function public.hub_context(),public.hub_save_record(text,text,jsonb),public.hub_radar(text,jsonb),
 public.hub_radar_feed(jsonb),public.hub_team(),public.hub_editorial_save(text,text,integer,jsonb),public.hub_calendar(text) to authenticated;
