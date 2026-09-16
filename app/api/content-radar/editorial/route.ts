import {db} from '@/lib/storage';
import {requireRadarStaff,radarError} from '@/lib/content-radar/server';
import {RadarError} from '@/lib/content-radar/repository';
import {readEditorial,saveEditorial,addToCalendar} from '@/lib/content-radar/editorial-repository';
export const dynamic='force-dynamic';
export async function GET(){try{return Response.json(await readEditorial(db(),await requireRadarStaff()),{headers:{'Cache-Control':'no-store'}});}catch(e){return radarError(e);}}
export async function POST(request:Request){try{const s=await requireRadarStaff(request);const reader=request.body?.getReader();if(!reader)throw new RadarError(400,'Missing input.');let raw='';const decoder=new TextDecoder();let size=0;while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>30000){await reader.cancel();throw new RadarError(413,'Record too large.');}raw+=decoder.decode(value,{stream:true});}raw+=decoder.decode();let input;try{input=JSON.parse(raw);}catch{throw new RadarError(400,'Invalid JSON.');}if(input.action==='calendar'&&typeof input.id==='string')return Response.json(await addToCalendar(db(),s,input.id));return Response.json(await saveEditorial(db(),s,input),{headers:{'Cache-Control':'no-store'}});}catch(e){return radarError(e);}}
