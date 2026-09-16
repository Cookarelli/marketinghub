import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {blankQueue,blankDetail} from '../lib/content-radar/editorial-model.ts';

let db;
const admin='00000000-0000-4000-8000-000000000001',staff='00000000-0000-4000-8000-000000000002',outsider='00000000-0000-4000-8000-000000000003',unconfirmed='00000000-0000-4000-8000-000000000004';
async function actor(id){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec('set role authenticated');}
async function rpc(name,...args){const r=await db.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) as result`,args);return r.rows[0].result;}
async function radar(action,data){return rpc('hub_radar',action,JSON.stringify(data));}
async function save(id,version,data,kind='queue'){return rpc('hub_editorial_save',kind,id,version,JSON.stringify(data));}
before(async()=>{
 db=new PGlite();
 await db.exec(`create role anon; create role authenticated;create role service_role;
 create schema auth; create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;
 create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid,name text,bucket_id text,metadata jsonb);alter table storage.objects enable row level security;grant usage on schema storage to authenticated;grant select,insert on storage.objects to authenticated;`);
 for(const file of ['schema','records','radar','feed','editorial','permissions'])await db.exec(await readFile(new URL('../supabase/'+file+'.sql',import.meta.url),'utf8'));
 await db.query(`insert into auth.users values($1,'admin@example.test',now()),($2,'staff@example.test',now()),($3,'outsider@example.test',now()),($4,'pending@example.test',null)`,[admin,staff,outsider,unconfirmed]);
 await db.exec(`insert into private.staff_access(email,org_id,id,name,role) values('admin@example.test','northside-marketing','admin','Admin','admin'),('staff@example.test','northside-marketing','staff','Staff','staff'),('pending@example.test','northside-marketing','pending','Pending','staff');`);
});
after(async()=>{await db?.close();});

test('anonymous, unconfirmed and nonstaff access denied; client cannot mutate tables',async()=>{
 await db.exec('set role anon');await assert.rejects(rpc('hub_context'),/permission denied/);
 for(const id of [outsider,unconfirmed]){await actor(id);assert.equal((await rpc('hub_context')).orgId,null);assert.equal((await db.query('select * from public.radar_items')).rows.length,0);await assert.rejects(radar('add-source',{data:{name:'X',url:'https://x.test',category:'Baseball'}}),/Staff access required/);}
 await actor(staff);assert.equal((await rpc('hub_context')).role,'staff');
 await assert.rejects(db.exec("insert into public.radar_organizations values('evil','Evil')"),/permission denied/);
});
test('story save, deduplication, search pagination, history and review permissions',async()=>{
 await actor(staff);
 const item=await radar('add-item',{data:{title:'QA release',url:'https://example.test/story',sourceId:null,category:'Baseball',kind:'release',priority:'high',publishedAt:null,eventDate:null,summary:'A new release',tags:[]}});
 await assert.rejects(radar('add-item',{data:{title:'Duplicate',url:'https://example.test/story',sourceId:null,category:'Baseball',kind:'story',priority:'normal',summary:'',tags:[]}}),/duplicate key/);
 await radar('save-idea',{id:item.id,blankQueue:{...blankQueue,state:'Approved'}});
 let q=(await db.query("select * from public.radar_editorial where id=$1",[item.id])).rows[0];assert.equal(q.data.state,'Saved');
 const f={tab:'releases',q:'qa release',category:'all',priority:'all',source:'all',status:'all',after:'',before:'',offset:0};
 assert.equal((await rpc('hub_radar_feed',JSON.stringify(f))).total,1);
 assert.equal((await rpc('hub_radar_feed',JSON.stringify({...f,q:'%'}))).total,0);
 const review={...q.data,state:'Needs review',facebook:'Facebook copy',instagram:'Instagram copy',reel:'Reel outline',cta:'Visit us',calendarDate:'2026-09-20T12:30'};
 await save(item.id,1,review);
 await assert.rejects(save(item.id,1,review),/Someone edited/);
 await assert.rejects(save(item.id,2,{...review,state:'Approved'}),/administrator/);
 await actor(admin);
 await save(item.id,2,{...review,state:'Approved'});await rpc('hub_calendar',item.id);
 let post=(await db.query("select data from public.marketing_records where kind='post'")).rows[0].data;assert.equal(post.status,'approved');
 await actor(staff);
 await assert.rejects(rpc('hub_save_record','post','radar_'+item.id,JSON.stringify({...post,status:'published'})),/editorial review/);
 await save(item.id,3,{...review,state:'Approved',facebook:'Changed after approval'});
 q=(await db.query("select * from public.radar_editorial where id=$1",[item.id])).rows[0];assert.equal(q.data.state,'Needs review');
 post=(await db.query("select data from public.marketing_records where kind='post'")).rows[0].data;assert.equal(post.status,'review');
 await assert.rejects(rpc('hub_calendar',item.id),/Approve/);
 assert.ok((await db.query('select * from public.radar_workflow_history')).rows.length>=2);
});
test('source leases, publisher versions, retry dedupe and stale settings are enforced',async()=>{
 await actor(staff);
 await radar('seed-sources',{sources:[{key:'test',name:'Test source',url:'https://example.test/feed',category:'Baseball',priority:'normal',feed:'https://example.test/feed'}]});
 const lease=await radar('acquire-source',{});assert.ok(lease.token);assert.equal(await radar('acquire-source',{id:lease.source.id}),null);
 const info={sourceId:lease.source.id,token:lease.token,runId:lease.runId,version:lease.source.config_version};
 const entry={key:'1',title:'Collected story',url:'https://example.test/collected',originalUrl:'https://example.test/collected',kind:'story',summary:'Publisher text',publishedAt:null,eventDate:null,fingerprint:'first',group:'first'};
 assert.equal((await radar('ingest-entries',{...info,entries:[entry]})).added,1);
 assert.equal((await radar('ingest-entries',{...info,entries:[entry]})).duplicates,1);
 assert.equal((await radar('ingest-entries',{...info,entries:[{...entry,summary:'Updated',fingerprint:'second'}]})).updates,1);
 await radar('edit-source',{id:lease.source.id,data:{name:'Test source',url:'https://example.test/feed',category:'Baseball',priority:'normal',enabled:false,mode:'manual'}});
 await assert.rejects(radar('ingest-entries',{...info,entries:[entry]}),/Source settings changed/);
 assert.equal((await radar('finish-source',{...info,data:{status:'success'}})).stale,true);
});
test('team access cannot escalate, self-revoke, or survive revocation',async()=>{
 await actor(staff);let members=await rpc('hub_team');const self=members.find(t=>t.id==='staff');
 await assert.rejects(save('staff',self.version,{...self.data,role:'admin'},'team'),/Only administrators/);
 await actor(admin);members=await rpc('hub_team');const me=members.find(t=>t.id==='admin');
 await assert.rejects(save('admin',me.version,{...me.data,active:false},'team'),/own administrator/);
 await save('staff',self.version,{...self.data,active:false},'team');await actor(staff);
 assert.equal((await rpc('hub_context')).orgId,null);await assert.rejects(radar('acquire-source',{}),/Staff access required/);
});
