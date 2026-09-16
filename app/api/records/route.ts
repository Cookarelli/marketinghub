import {listRecords,identity,saveRecord,apiError} from '@/lib/storage';
import {z} from 'zod';
const kinds=z.enum(['plan','post','link','metrics','clipjob']);
const schema=z.object({kind:kinds,id:z.string().min(1).max(180),data:z.record(z.unknown())});
const source=z.enum(['facebook','instagram','x','tiktok','snapchat','google','email','offline']);
const n=z.number().finite().nonnegative();
const validators={
 plan:z.object({budget:z.union([z.literal(1000),z.literal(2000),z.literal(3000),z.literal(5000)]),launchDate:z.string(),address:z.string().max(500),campaign:z.string().min(1).max(150),aov:z.number().positive(),margin:z.number().positive().max(100)}),
 post:z.object({title:z.string().min(1).max(500),date:z.string().min(10),timezone:z.literal('America/Chicago'),source:z.string(),caption:z.string().max(10000),status:z.enum(['draft','review','approved','published'])}),
 link:z.object({name:z.string().max(500),url:z.string().url().refine(u=>u.startsWith('https://')),source:z.string(),medium:z.string(),campaign:z.string(),content:z.string()}),
 metrics:z.object({date:z.string().regex(/^\d{4}-\d{2}-\d{2}$/),source,campaign:z.string().min(1).max(150),spend:n,impressions:n.int(),clicks:n.int(),leads:n.int(),onlineOrders:n.int(),onlineRevenue:n,posOrders:n.int(),posRevenue:n}).passthrough(),
 clipjob:z.object({name:z.string().max(500),assetId:z.string(),transcript:z.string().max(1000000),signals:z.string().max(2000),before:n,after:z.number().positive(),duration:z.number().positive(),clips:z.array(z.object({id:z.string(),start:n,end:z.number().positive(),signal:z.string(),text:z.string(),approved:z.boolean(),caption:z.string(),triggerTime:n.optional()})).max(1000)}).refine(j=>j.clips.every(c=>c.start<c.end&&c.end<=j.duration))
};
export async function GET(request:Request){try{const owner=await identity();const cursor=Number(new URL(request.url).searchParams.get('cursor')||0);if(!Number.isSafeInteger(cursor)||cursor<0)return Response.json({error:'Invalid page.'},{status:400});return Response.json(await listRecords(owner,cursor),{headers:{'Cache-Control':'private, no-store'}});}catch(e){return apiError(e);}}
export async function POST(request:Request){try{const owner=await identity(request);const raw=await request.text();if(Buffer.byteLength(raw)>1500000)return Response.json({error:'Record is too large.'},{status:413});let json;try{json=JSON.parse(raw);}catch{return Response.json({error:'Invalid JSON.'},{status:400});}const parsed=schema.safeParse(json);if(!parsed.success)return Response.json({error:'Invalid record.'},{status:400});const {kind,id,data}=parsed.data;const valid=validators[kind].safeParse(data);if(!valid.success)return Response.json({error:'Check the required fields, dates, numbers and clip boundaries.'},{status:400});await saveRecord(owner,kind,id,valid.data);return Response.json({ok:true});}catch(e){return apiError(e);}}
