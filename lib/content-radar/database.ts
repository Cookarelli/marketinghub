import type {SupabaseClient} from '@supabase/supabase-js';
export type Database = Promise<SupabaseClient>;
export class RadarError extends Error {
  status:number;
  constructor(status:number,message:string){super(message);this.status=status;}
}
export function check(error:{code?:string;message:string}|null){
 if(!error)return;
 const status=error.code==='42501'?403:error.code==='P0002'?404:['23505','40001'].includes(error.code||'')?409:['22023','23514','23503'].includes(error.code||'')?400:503;
 throw new RadarError(status,status===503?'Saved workspace is unavailable. Please retry.':error.code==='23505'?'That record is already saved.':error.message);
}
export async function command(db:Database,action:string,data:unknown){
 const result=await (await db).rpc('hub_radar',{p_action:action,p_data:data});check(result.error);return result.data;
}
