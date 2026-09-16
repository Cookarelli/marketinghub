import {sessionClient} from '@/lib/supabase';
import {identity} from '@/lib/storage';
import {findStaff,RadarError} from './repository.ts';
export async function requireRadarStaff(request?:Request){
 try{await identity(request);}catch(e){throw new RadarError(e instanceof Error&&e.message==='Forbidden'?403:401,'Sign in with your approved team email to continue.');}
 if(request&&!['GET','HEAD'].includes(request.method)&&!request.headers.get('content-type')?.startsWith('application/json'))throw new RadarError(415,'Send JSON.');
 const staff=await findStaff(sessionClient());if(!staff)throw new RadarError(403,'Your account does not have staff access.');return staff;
}
export function radarError(error:unknown){
 if(error instanceof RadarError)return Response.json({error:error.message},{status:error.status,headers:{'Cache-Control':'no-store'}});
 console.error('Content Radar storage request failed');
 return Response.json({error:'Content Radar storage is unavailable. Your input has been kept. Please retry.'},{status:503,headers:{'Cache-Control':'no-store'}});
}
