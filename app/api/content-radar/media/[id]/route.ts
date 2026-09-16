import {db,bucket,getRecord} from '@/lib/storage';
import {requireRadarStaff,radarError} from '@/lib/content-radar/server';
import {RadarError} from '@/lib/content-radar/repository';
import {check} from '@/lib/content-radar/database';
export async function GET(_request:Request,{params}:{params:Promise<{id:string}>}){
 try{const staff=await requireRadarStaff(),{id}=await params;
 const {data,error}=await (await db()).from('radar_editorial').select('data').eq('org_id',staff.orgId).eq('kind','queue').eq('id',id).maybeSingle();check(error);
 if(!data?.data?.assetId)throw new RadarError(404,'No attached media.');
 const asset=await getRecord(staff.orgId,'asset',data.data.assetId);if(!asset)throw new RadarError(404,'Media unavailable.');
 const signed=await (await bucket()).createSignedUrl(asset.key,300);check(signed.error);
 return new Response(null,{status:307,headers:{Location:signed.data!.signedUrl,'Cache-Control':'private, no-store','Referrer-Policy':'no-referrer'}});
 }catch(e){return radarError(e);}
}
