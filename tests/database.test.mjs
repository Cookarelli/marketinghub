import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
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
 for(const file of (await readdir(new URL('../supabase/migrations/',import.meta.url))).filter(f=>/_consignment_(campaigns|preserve_published_history)\.sql$/.test(f)).sort()) await db.exec(await readFile(new URL('../supabase/migrations/'+file,import.meta.url),'utf8'));
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
test('campaign saves are atomic, authorized, retry-safe and reject stale reschedules',async()=>{
 await actor(staff);
 const cid='11111111-1111-4111-8111-111111111111';
 const campaign={name:'Fictional Meteor Batch',opening:'2026-09-20T10:00',closing:'2026-09-27T18:00',midweek:'2026-09-23T12:00',recap:'2026-09-28T12:00',auctionPlatform:'Example Auction',batchUrl:'https://example.test/batch',cards:[{name:'Fictional Card',url:'https://example.test/lot'}],owner:'staff',platforms:['instagram'],testPlatform:''};
 const stages=['opening','midweek','reminder','closing','recap'];
 const posts=stages.map(stage=>({id:`consignment_${cid}_${stage}`,data:{title:'Fictional '+stage,date:'2026-09-23T12:00',timezone:'America/Chicago',source:'instagram',platforms:['instagram'],caption:'Draft',status:'draft',category:'Consignment',owner:'staff',tasks:[],assets:[],references:[],consignment:{campaignId:cid,stage,slot:stage}}}));
 await rpc('hub_save_record','post','fictional-existing',JSON.stringify({title:'Existing fictional post',date:'2026-09-22T12:00',status:'draft'}));
 await rpc('hub_save_record','post','fictional-tuesday',JSON.stringify({title:'Fictional Tuesday series',date:'2026-09-15T12:00',recurrence:'weekly-tuesday',status:'draft'}));
 const untouched=(await db.query("select id,data from public.marketing_records where id in ('fictional-existing','fictional-tuesday') order by id")).rows;
 const payload={id:cid,mutationId:'22222222-2222-4222-8222-222222222222',campaign,posts,base:{campaign:null,posts:[]}};
 const saveCampaign=p=>rpc('hub_save_campaign',JSON.stringify(p));
 await actor(outsider);await assert.rejects(saveCampaign(payload),/Staff access required/);
 await db.exec('reset role; set role anon');await assert.rejects(saveCampaign(payload),/permission denied/);
 await actor(staff);
 await assert.rejects(saveCampaign({...payload,posts:posts.map((p,i)=>i===4?{...p,data:{...p.data,owner:'outsider'}}:p)}),/owner/);
 assert.equal((await db.query("select * from public.marketing_records where kind='campaign'")).rows.length,0);
 await assert.rejects(saveCampaign({...payload,campaign:{...campaign,opening:'2026-03-08T02:30'}}),/Chicago time/);
 await saveCampaign(payload);await saveCampaign(payload);
 assert.equal((await db.query("select * from public.marketing_records where kind='post' and id like 'consignment_%'")).rows.length,5);
 await assert.rejects(saveCampaign({...payload,campaign:{...campaign,name:'Changed'}}),/Retry identifier/);
 await rpc('hub_save_record','post',posts[0].id,JSON.stringify({...posts[0].data,caption:'Staff edit after save'}));
 await saveCampaign(payload);
 assert.equal((await db.query("select data from public.marketing_records where id=$1",[posts[0].id])).rows[0].data.caption,'Staff edit after save');
 await assert.rejects(saveCampaign({...payload,mutationId:'33333333-3333-4333-8333-333333333333',base:{campaign,posts}}),/Someone edited/);
 await assert.rejects(rpc('hub_save_record','post',posts[0].id,JSON.stringify({...posts[0].data,consignment:undefined})),/campaign membership/);
 const current=posts.map((p,i)=>i===0?{...p,data:{...p.data,caption:'Staff edit after save'}}:p);
 const revised=current.map(p=>({...p,data:{...p.data,date:'2026-09-24T12:00'}}));
 await saveCampaign({...payload,mutationId:'44444444-4444-4444-8444-444444444444',posts:revised,base:{campaign,posts:current}});
 assert.equal((await db.query("select data from public.marketing_records where id=$1",[posts[0].id])).rows[0].data.caption,'Staff edit after save');
 assert.deepEqual((await db.query("select id,data from public.marketing_records where id in ('fictional-existing','fictional-tuesday') order by id")).rows,untouched);
 await assert.rejects(db.exec('select * from private.campaign_receipts'),/permission denied/);
});
test('approval gates cannot be bypassed through either RPC and reviewed facts persist',async()=>{
 await actor(staff);
 const cid='55555555-5555-4555-8555-555555555555';
 const campaign={name:'Fictional Review Batch',opening:'2026-03-05T10:00',closing:'2026-03-09T18:00',midweek:'2026-03-07T12:00',recap:'2026-03-10T12:00',auctionPlatform:'Example',batchUrl:'https://example.test/review',cards:[{name:'Fictional Sold Card',url:'https://example.test/sold'},{name:'Fictional Unsold Card',url:'https://example.test/unsold'}],owner:'staff',platforms:['instagram'],testPlatform:''};
 const {generateCampaign}=await import('../lib/consignment.ts');
 const {auctionFacts,verifiedRecap}=await import('../lib/consignment-review.ts');
 const posts=generateCampaign(cid,campaign);
 const base={campaign:null,posts:[]};
 await rpc('hub_save_campaign',JSON.stringify({id:cid,mutationId:'66666666-6666-4666-8666-666666666666',campaign,posts,base}));
 const closing=posts[3];
 const savePost=data=>rpc('hub_save_record','post',closing.id,JSON.stringify(data));
 await assert.rejects(savePost({...closing.data,status:'approved'}),/asset/);
 let ready={...closing.data,status:'approved',assets:['fictional-art'],completedTasks:closing.data.tasks,caption:'Closes March 9 at 6 p.m. CT.'};
 await assert.rejects(savePost(ready),/Verify/);
 ready.verification={auction:auctionFacts(campaign),closing:campaign.closing,lotLinksChecked:true,reviewedCaption:ready.caption};
 await assert.rejects(savePost({...ready,references:[]}),/lot link/);
 await assert.rejects(savePost({...ready,verification:{...ready.verification,closing:'2026-03-09T19:00'}}),/deadline/);
 await savePost(ready);
 const reread=(await db.query("select data from public.marketing_records where id=$1",[closing.id])).rows[0].data;
 assert.deepEqual(reread,ready);
 await assert.rejects(savePost({...ready,caption:'Changed facts'}),/caption/);
 const recap=posts[4];const results=[{url:campaign.cards[0].url,outcome:'sold',price:25,currency:'USD'},{url:campaign.cards[1].url,outcome:'unsold'}];
 const caption=verifiedRecap(campaign,results);
 const recapReady={...recap.data,status:'approved',caption,assets:['fictional-recap'],completedTasks:recap.data.tasks,verification:{auction:auctionFacts(campaign),results,resultsChecked:true,reviewedCaption:caption}};
 await assert.rejects(rpc('hub_save_record','post',recap.id,JSON.stringify({...recapReady,verification:{...recapReady.verification,resultsChecked:false}})),/Verify final/);
 await assert.rejects(rpc('hub_save_record','post',recap.id,JSON.stringify({...recapReady,verification:{...recapReady.verification,results:[results[0],{...results[1],price:99}]}})),/Only sold/);
 await rpc('hub_save_record','post',recap.id,JSON.stringify(recapReady));
 const current=posts.map(p=>p.id===closing.id?{...p,data:ready}:p.id===recap.id?{...p,data:recapReady}:p);
 const changedCampaign={...campaign,closing:'2026-03-09T20:00'};
 await assert.rejects(rpc('hub_save_campaign',JSON.stringify({id:cid,mutationId:'77777777-7777-4777-8777-777777777777',campaign:changedCampaign,posts:current,base:{campaign,posts:current}})),/current auction facts/);
 // No partial campaign mutation after rejected approval.
 assert.deepEqual((await db.query("select data from public.marketing_records where kind='campaign' and id=$1",[cid])).rows[0].data,campaign);
 const {rescheduleCampaign}=await import('../lib/consignment.ts');
 const changed=rescheduleCampaign(campaign,changedCampaign,current);
 await rpc('hub_save_campaign',JSON.stringify({id:cid,mutationId:'88888888-8888-4888-8888-888888888888',campaign:changedCampaign,posts:changed,base:{campaign,posts:current}}));
 const persisted=(await db.query("select data from public.marketing_records where id=$1",[recap.id])).rows[0].data;
 assert.equal(persisted.status,'review');assert.equal(persisted.caption,caption);assert.deepEqual(persisted.completedTasks,recap.data.tasks);
 await actor(outsider);assert.equal((await db.query("select * from public.marketing_records where kind='campaign' or id like 'consignment_%'")).rows.length,0);
 await assert.rejects(rpc('hub_save_record','post',closing.id,JSON.stringify(ready)),/Staff access/);
 await db.exec('reset role; set role anon');await assert.rejects(db.exec("select * from public.marketing_records"),/permission denied/);
});
test('published history remains intact across repeated campaign reschedules',async()=>{
 await actor(staff);
 const cid='55555555-5555-4555-8555-555555555555';
 const {rescheduleCampaign}=await import('../lib/consignment.ts');
 const {auctionFacts}=await import('../lib/consignment-review.ts');
 let campaign=(await db.query("select data from public.marketing_records where kind='campaign' and id=$1",[cid])).rows[0].data;
 const closing=(await db.query("select id,data from public.marketing_records where data->'consignment'->>'campaignId'=$1 and data->'consignment'->>'stage'='closing'",[cid])).rows[0];
 const published={...closing.data,status:'published',verification:{auction:auctionFacts(campaign),closing:campaign.closing,lotLinksChecked:true,reviewedCaption:closing.data.caption}};
 await rpc('hub_save_record','post',closing.id,JSON.stringify(published));
 for(const [index,time] of ['21:00','22:00'].entries()){
  const posts=(await db.query("select id,data from public.marketing_records where data->'consignment'->>'campaignId'=$1 order by id",[cid])).rows;
  const next={...campaign,closing:'2026-03-09T'+time};
  const rescheduled=rescheduleCampaign(campaign,next,posts);
  await rpc('hub_save_campaign',JSON.stringify({id:cid,mutationId:`aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa${index}`,campaign:next,posts:rescheduled,base:{campaign,posts}}));
  assert.deepEqual((await db.query("select data from public.marketing_records where id=$1",[closing.id])).rows[0].data,published);
  campaign=next;
 }
});
test('campaign data and production edits survive a database restart, with workspace isolation',async()=>{
 await actor(staff);
 const before=(await db.query("select kind,id,data from public.marketing_records where kind='campaign' or id like 'consignment_%' order by kind,id")).rows;
 await db.exec('reset role');
 const dump=await db.dumpDataDir();
 const reopened=new PGlite({loadDataDir:dump});
 try {
  await reopened.query("select set_config('request.jwt.claim.sub',$1,false)",[staff]);await reopened.exec('set role authenticated');
  assert.deepEqual((await reopened.query("select kind,id,data from public.marketing_records where kind='campaign' or id like 'consignment_%' order by kind,id")).rows,before);
  await reopened.exec("reset role; insert into auth.users values('99999999-9999-4999-8999-999999999999','other-workspace@example.test',now()); insert into private.staff_access(email,org_id,id,name,role) values('other-workspace@example.test','fictional-other-workspace','other-staff','Other Fictional Staff','staff');");
  await reopened.query("select set_config('request.jwt.claim.sub',$1,false)",['99999999-9999-4999-8999-999999999999']);await reopened.exec('set role authenticated');
  assert.equal((await reopened.query("select * from public.marketing_records")).rows.length,0);
  await assert.rejects(reopened.query("select public.hub_save_record('post',$1,$2)",[before.find(r=>r.kind==='post').id,JSON.stringify(before.find(r=>r.kind==='post').data)]),/campaign membership/);
 } finally {await reopened.close();}
});
test('team access cannot escalate, self-revoke, or survive revocation',async()=>{
 await actor(staff);let members=await rpc('hub_team');const self=members.find(t=>t.id==='staff');
 await assert.rejects(save('staff',self.version,{...self.data,role:'admin'},'team'),/Only administrators/);
 await actor(admin);members=await rpc('hub_team');const me=members.find(t=>t.id==='admin');
 await assert.rejects(save('admin',me.version,{...me.data,active:false},'team'),/own administrator/);
 await save('staff',self.version,{...self.data,active:false},'team');await actor(staff);
 assert.equal((await rpc('hub_context')).orgId,null);await assert.rejects(radar('acquire-source',{}),/Staff access required/);
});
