import {retrieveMetadata} from '../lib/content-radar/collect.ts';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {canonicalUrl,fetchUrl} from '../lib/content-radar/urls.ts';
import {createReader} from '../lib/content-radar/fetch.ts';
import {parseFeed,retained,robotsAllowed} from '../lib/content-radar/parse.ts';
const rss=(items)=>`<?xml version="1.0"?><rss version="2.0"><channel>${items.map((x)=>`<item><guid>${x.key}</guid><title>${x.title}</title><link>${x.url}</link>${x.publishedAt?`<pubDate>${x.publishedAt}</pubDate>`:''}<description>${x.summary||''}</description></item>`).join('')}</channel></rss>`;
const item=(patch={})=>({key:'card-1',url:'https://www.pokebeach.com/cards/2026-a',title:'2026 Set A card 12/99',summary:'Publisher excerpt',publishedAt:new Date().toISOString().slice(0,10),eventDate:null,updatedAt:null,...patch});
test('RSS/Atom dates, untrusted markup, malformed XML and old versus upcoming releases',()=>{
 const feed=parseFeed(rss([item({publishedAt:null,title:'&lt;script&gt;bad&lt;/script&gt;Safe title'})]),'https://www.pokebeach.com/');assert.equal(feed.entries[0].publishedAt,null);assert.equal(feed.entries[0].title,'Safe title');
 assert.equal(parseFeed('<feed xmlns="http://www.w3.org/2005/Atom"><entry><id>x</id><title>Hello</title><link href="https://www.pokebeach.com/a"/><updated>2026-09-15</updated></entry></feed>','https://www.pokebeach.com/').entries[0].publishedAt,null);
 assert.throws(()=>parseFeed('<rss><item>','https://www.pokebeach.com/'),/incomplete/);assert.throws(()=>parseFeed('<!DOCTYPE rss><rss></rss>','https://www.pokebeach.com/'),/declarations/);
 assert.equal(retained([item({publishedAt:'2020-01-01'}),item({publishedAt:'2020-01-01',eventDate:'2027-01-01'}),item({publishedAt:null})],new Date('2026-09-15')).length,2);
 assert.equal(robotsAllowed('User-agent: *\nDisallow: /private', 'https://www.pokebeach.com/private/a'),false);
});
test('URL policy rejects private, credentialed, non-HTTPS and unsafe redirect targets',async()=>{
 for(const url of ['http://www.pokebeach.com/','https://127.0.0.1/','https://2130706433/','https://[::1]/','https://169.254.169.254/','https://localhost/','https://www.pokebeach.com.evil.test/','https://user:secret@www.pokebeach.com/','https://www.pokebeach.com:8443/'])assert.throws(()=>fetchUrl(url,'https://www.pokebeach.com/'));
 assert.equal(canonicalUrl('https://www.pokebeach.com/a?card=12%2F99&utm_source=x#top'),'https://www.pokebeach.com/a?card=12%2F99');
 let calls=0;const reader=createReader('https://www.pokebeach.com/',{transport:async()=>{calls++;return new Response('',{status:302,headers:{location:'http://169.254.169.254/latest/meta-data/'}});}});await assert.rejects(reader('https://www.pokebeach.com/'),/approved domain/);assert.equal(calls,1);
 const tooBig=createReader('https://www.pokebeach.com/',{transport:async()=>new Response('x'.repeat(1500001),{headers:{'content-type':'text/html'}})});await assert.rejects(tooBig('https://www.pokebeach.com/'),/size limit/);
 assert.equal((await retrieveMetadata('https://www.instagram.com/p/abc/')).manual,true);
});
