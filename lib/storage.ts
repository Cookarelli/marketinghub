import {sessionClient} from './supabase';
export const db = sessionClient;
export async function identity(request?: Request) {
  if (request && !['GET','HEAD'].includes(request.method)) {
    const origin = request.headers.get('origin');
    if (!origin || origin !== new URL(request.url).origin) throw new Error('Forbidden');
  }
  const client = await sessionClient();
  const {data:{user},error} = await client.auth.getUser();
  if (error || !user || !user.email_confirmed_at) throw new Error('Unauthorized');
  const {data:staff,error:accessError}=await client.rpc('hub_context');
  if(accessError || !staff?.orgId) throw new Error('Forbidden');
  return staff.orgId as string;
}
export const bucket = async () => (await sessionClient()).storage.from('marketing-assets');
export async function listRecords(workspace:string,offset=0) {
  const {data,error}=await (await sessionClient()).from('marketing_records').select('kind,id,data,updated_at').eq('workspace_id',workspace).neq('kind','upload').order('kind').order('id').range(offset,offset+49);
  if(error)throw error;
  const records:typeof data=[];let bytes=0;
  for(const record of data){const size=Buffer.byteLength(JSON.stringify(record));if(records.length&&bytes+size>2500000)break;records.push(record);bytes+=size;}
  return {records,nextCursor:records.length<data.length||data.length===50?offset+records.length:null};
}
export async function getRecord(workspace:string,kind:string,id:string) {
  const {data,error} = await (await sessionClient()).from('marketing_records').select('data').eq('workspace_id',workspace).eq('kind',kind).eq('id',id).maybeSingle();
  if (error) throw error;
  return data?.data || null;
}
export async function saveRecord(workspace:string,kind:string,id:string,data:unknown) {
  const {error} = await (await sessionClient()).rpc('hub_save_record',{p_kind:kind,p_id:id,p_data:data});
  if (error) throw error;
}
export function apiError(error:unknown) {
  if (error && typeof error === 'object' && 'code' in error && error.code === '22023' && 'message' in error) return Response.json({error:String(error.message)},{status:400,headers:{'Cache-Control':'no-store'}});
  const message = error instanceof Error ? error.message : '';
  const status = message==='Unauthorized'?401:message==='Forbidden'?403:503;
  const text = status===401?'Please sign in to open the team workspace.':status===403?'Your account does not have access to this action.':message==='Setup required'?'Team workspace setup is not complete.':'Could not reach the saved workspace. Your entries remain here; please retry.';
  return Response.json({error:text},{status,headers:{'Cache-Control':'no-store'}});
}
