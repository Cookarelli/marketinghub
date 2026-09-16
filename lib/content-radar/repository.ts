import type {RadarCommand,Filters,RadarData,Item,Source,Draft,History,Publication} from './model.ts';
import {blankQueue} from './editorial-model.ts';
import {command,check,type Database} from './database.ts';
export {RadarError} from './database.ts';
export type Staff={orgId:string;userId:string;orgName:string;role:'admin'|'staff'};
export async function findStaff(db:Database):Promise<Staff|null>{
 const {data,error}=await (await db).rpc('hub_context');check(error);return data?.orgId?data:null;
}
export async function readRadar(db:Database,s:Staff,f:Filters):Promise<RadarData>{
 const client=await db;
 const response=await client.rpc('hub_radar_feed',{p_filters:f});check(response.error);
 const {items,total}=response.data as {items:Item[];total:number};const ids=items.map(i=>i.id);
 const [sources,runs,drafts,history,publications]=await Promise.all([
  client.from('radar_sources').select('*').eq('org_id',s.orgId).order('name').limit(500),
  client.from('radar_ingestion_runs').select('*').eq('org_id',s.orgId).order('started_at',{ascending:false}).limit(30),
  client.from('radar_drafts').select('*').eq('org_id',s.orgId).in('item_id',ids).limit(50),
  client.from('radar_workflow_history').select('*').eq('org_id',s.orgId).in('item_id',ids).order('created_at',{ascending:false}).limit(500),
  client.from('radar_publications').select('*').eq('org_id',s.orgId).in('item_id',ids).order('observed_at',{ascending:false}).limit(300),
 ]);
 for(const result of [sources,runs,drafts,history,publications])check(result.error);
 const names=new Map((sources.data||[]).map(v=>[v.id,v.name]));
 return {items:items.map(i=>({...i,source_name:names.get(i.source_id)||null})),total,hasMore:f.offset+items.length<total,
  sources:sources.data as Source[],runs:(runs.data||[]).map(r=>({...r,source_name:names.get(r.source_id)||null})) as RadarData['runs'],
  drafts:drafts.data as Draft[],history:history.data as History[],publications:(publications.data||[]).map(p=>({...p,source_name:names.get(p.source_id)||''})) as Publication[]};
}
export async function executeRadar(db:Database,_s:Staff,c:RadarCommand){return command(db,c.action,{...c,...(c.action==='save-idea'?{blankQueue}:{})});}
