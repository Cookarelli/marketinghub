import {test} from 'node:test';
import assert from 'node:assert/strict';
import {chicagoInstant, stageDates, generateCampaign, rescheduleCampaign, scheduleWarnings} from '../lib/consignment.ts';
const id='11111111-1111-4111-8111-111111111111';
const campaign={name:'Fictional Comet auction',opening:'2026-03-05T10:00',closing:'2026-03-09T18:00',midweek:'2026-03-07T12:00',recap:'2026-03-10T12:00',auctionPlatform:'Fictional Auction House',batchUrl:'https://example.test/batch',cards:[{name:'Imaginary Comet Rookie',url:'https://example.test/lot/1'}],owner:'fictional-staff',platforms:['instagram'],testPlatform:'youtube'};
test('48-hour reminder accounts for spring and fall DST',()=>{
 assert.equal(stageDates(campaign).reminder,'2026-03-07T17:00');
 const fall={...campaign,opening:'2026-10-28T10:00',closing:'2026-11-02T18:00',midweek:'2026-10-30T12:00',recap:'2026-11-03T12:00'};
 assert.equal(stageDates(fall).reminder,'2026-10-31T19:00');
 for(const c of [campaign,fall]) assert.equal(chicagoInstant(c.closing)-chicagoInstant(stageDates(c).reminder),48*3600000);
 for(const date of ['2026-03-08T02:30','2026-11-01T01:30','2026-02-30T10:00','garbage']) assert.throws(()=>chicagoInstant(date));
});
test('generation, staff edits, extra spotlights and manual schedule offsets survive rescheduling',()=>{
 const posts=generateCampaign(id,campaign);assert.equal(posts.length,5);assert.ok(posts.every(p=>p.data.status==='draft'));
 assert.ok(posts[1].data.platforms.includes('youtube'));
 posts[1].data.caption='Fictional staff edit';posts[1].data.tasks=['Custom task'];posts[1].data.date='2026-03-07T13:00';posts[1].data.status='review';
 posts.push({...posts[1],id:`consignment_${id}_extra`,data:{...posts[1].data,consignment:{campaignId:id,stage:'midweek',slot:'extra'}}});
 const result=rescheduleCampaign(campaign,{...campaign,midweek:'2026-03-07T14:00'},posts);
 assert.equal(result[1].data.date,'2026-03-07T15:00');assert.equal(result[1].data.caption,'Fictional staff edit');assert.deepEqual(result[1].data.tasks,['Custom task']);assert.equal(result[1].data.status,'review');assert.equal(result[5].id,posts[5].id);
 assert.equal(posts[1].data.date,'2026-03-07T13:00');
});
test('warnings include short auctions, Tuesday collisions and daily capacity without moving posts',()=>{
 const c={...campaign,opening:'2026-09-22T10:00',closing:'2026-09-23T18:00',midweek:'2026-09-22T12:00',recap:'2026-09-24T12:00'};
 const posts=generateCampaign(id,c);const existing=[10,11,12].map(hour=>({id:`series-${hour}`,data:{...posts[0].data,date:`2026-09-15T${hour}:00`,recurrence:'weekly-tuesday',consignment:undefined}}));
 const before=JSON.stringify(existing);const warnings=scheduleWarnings(posts,existing,c).join('\n');
 assert.match(warnings,/before listings open/);assert.match(warnings,/collision/);assert.match(warnings,/three-post target/);assert.equal(JSON.stringify(existing),before);
 assert.equal(scheduleWarnings(posts,[...existing,...posts],c).filter(w=>w.includes('three-post')).length,1);
});

test('API schemas retain optional metadata and reject unsafe URLs, identities and malformed times',async()=>{
 const {campaignSaveSchema,postSchema}=await import('../lib/calendar-validation.ts');
 const posts=generateCampaign(id,campaign);
 const payload={id,mutationId:'22222222-2222-4222-8222-222222222222',campaign,posts,base:{campaign:null,posts:[]}};
 assert.equal(campaignSaveSchema.safeParse(payload).success,true);
 assert.deepEqual(postSchema.parse(posts[0].data).consignment,posts[0].data.consignment);
 assert.equal(campaignSaveSchema.safeParse({...payload,posts:[...posts,posts[0]]}).success,false);
 assert.equal(campaignSaveSchema.safeParse({...payload,posts:posts.map(p=>({...p,id:'unrelated'}))}).success,false);
 assert.equal(campaignSaveSchema.safeParse({...payload,campaign:{...campaign,batchUrl:'javascript:alert(1)'}}).success,false);
 assert.equal(postSchema.safeParse({...posts[0].data,date:'2026-11-01T01:30'}).success,false);
 assert.equal(postSchema.safeParse({...posts[0].data,recurrence:'weekly-tuesday'}).success,false);
 assert.equal(postSchema.safeParse({title:'Existing Tuesday',date:'2026-09-15T12:00',timezone:'America/Chicago',source:'tbd',caption:'',status:'draft',recurrence:'weekly-tuesday'}).success,true);
});

test('closing approval requires facts, links, finished production and final caption review',async()=>{
 const {approvalIssues,auctionFacts}=await import('../lib/consignment-review.ts');
 const p=generateCampaign(id,campaign)[3].data;
 assert.ok(approvalIssues(p,campaign).length);
 const ready={...p,caption:'Fictional Comet auction closes March 9 at 6 p.m. CT.',assets:['fictional-creative'],completedTasks:p.tasks,verification:{closing:campaign.closing,lotLinksChecked:true,auction:auctionFacts(campaign)}};
 ready.verification.reviewedCaption=ready.caption;
 assert.deepEqual(approvalIssues(ready,campaign),[]);
 assert.ok(approvalIssues({...ready,references:[]},campaign).some(x=>x.includes('lot link')));
 assert.ok(approvalIssues({...ready,caption:'Changed closing claim'},campaign).some(x=>x.includes('caption')));
 const after={...campaign,closing:'2026-03-09T20:00'};
 const shifted=rescheduleCampaign(campaign,after,[{id:'closing',data:{...ready,status:'approved'}}])[0].data;
 assert.equal(shifted.status,'review');assert.equal(shifted.verification.auction,undefined);assert.equal(shifted.verification.lotLinksChecked,false);assert.deepEqual(shifted.completedTasks,ready.completedTasks);assert.equal(shifted.caption,ready.caption);
 const published={id:'published',data:{...ready,status:'published'}};
 assert.deepEqual(rescheduleCampaign(campaign,after,[published]),[published]);
});
test('recaps use only explicit outcomes and never fabricate sale prices',async()=>{
 const {approvalIssues,auctionFacts,verifiedRecap}=await import('../lib/consignment-review.ts');
 const c={...campaign,cards:[...campaign.cards,{name:'Fictional Unsold Card',url:'https://example.test/lot/2'}]};
 const results=[{url:c.cards[0].url,outcome:'sold'},{url:c.cards[1].url,outcome:'unsold'}];
 const caption=verifiedRecap(c,results);
 assert.match(caption,/Fictional Unsold Card: unsold/);assert.doesNotMatch(caption,/USD|\$/);assert.throws(()=>verifiedRecap(c,[{url:c.cards[0].url,outcome:'unknown'}]),/Verify/);
 const p=generateCampaign(id,c)[4].data;
 const ready={...p,caption,assets:['fictional-recap'],completedTasks:p.tasks,verification:{auction:auctionFacts(c),results,resultsChecked:true,reviewedCaption:caption}};
 assert.deepEqual(approvalIssues(ready,c),[]);
 const shifted=rescheduleCampaign(c,{...c,closing:'2026-03-09T20:00'},[{id:'recap',data:{...ready,status:'approved'}}])[0].data;
 assert.deepEqual(shifted.verification.results,results);assert.equal(shifted.verification.resultsChecked,false);
 assert.ok(approvalIssues({...ready,verification:{...ready.verification,results:[results[0]]}},c).some(x=>x.includes('every featured lot')));
 assert.ok(approvalIssues({...ready,verification:{...ready.verification,results:[results[0],{...results[1],price:100}]}},c).some(x=>x.includes('Only sold')));
});
