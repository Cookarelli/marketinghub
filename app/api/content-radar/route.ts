import { db } from '@/lib/storage';
import { commandInput, filterInput } from '@/lib/content-radar/model';
import { executeRadar, readRadar, RadarError } from '@/lib/content-radar/repository';
import { requireRadarStaff, radarError } from '@/lib/content-radar/server';
import { seedSources, editSource } from '@/lib/content-radar/collection-repository';
import { refreshSource, retrieveMetadata } from '@/lib/content-radar/collect';
export const dynamic='force-dynamic';
export async function GET(request:Request) {
 try {
  const staff=await requireRadarStaff(request);
  const filters=filterInput.safeParse(Object.fromEntries(new URL(request.url).searchParams));
  if(!filters.success)throw new RadarError(400,filters.error.issues[0]?.message||'Invalid filters.');
  return Response.json(await readRadar(db(),staff,filters.data),{headers:{'Cache-Control':'no-store'}});
 }catch(e){return radarError(e);}
}
export async function POST(request:Request) {
 try {
  const staff=await requireRadarStaff(request);
  // Bound the body while reading, including requests without Content-Length.
  const reader=request.body?.getReader(); if(!reader)throw new RadarError(400,'Missing request.');
  const chunks:Uint8Array[]=[];let size=0;
  while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>24000){await reader.cancel();throw new RadarError(413,'Content is too long.');}chunks.push(value);}
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  let json;try{json=JSON.parse(new TextDecoder().decode(bytes));}catch{throw new RadarError(400,'Invalid JSON.');}
  const command=commandInput.safeParse(json);
  if(!command.success)throw new RadarError(400,command.error.issues[0]?.message||'Check the required fields.');
  const c=command.data;
  const result=c.action==='seed-sources'?await seedSources(db(),staff):c.action==='edit-source'?await editSource(db(),staff,c.id,c.data):c.action==='refresh-sources'?await refreshSource(db(),staff,c.sourceId):c.action==='metadata'?await retrieveMetadata(c.url):await executeRadar(db(),staff,c);
  return Response.json(result,{headers:{'Cache-Control':'no-store'}});
 }catch(e){return radarError(e);}
}
