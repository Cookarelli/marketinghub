import {load} from 'cheerio/slim';
import {XMLValidator} from 'fast-xml-parser';
import {canonicalUrl} from './urls.ts';
import {CollectionError} from './fetch.ts';
export type Entry={key:string;url:string;title:string;summary:string;publishedAt:string|null;eventDate:string|null;updatedAt:string|null};
export function cleanText(value:string,limit=350){const $=load(value);$('script,style,iframe,object,template,noscript').remove();return $.text().replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g,'').replace(/\s+/g,' ').trim().slice(0,limit);}
export function knownDate(value:string|undefined|null):string|null {
 if(!value||!/(?:19|20)\d{2}/.test(value))return null;
 const ms=Date.parse(value.trim());if(!Number.isFinite(ms))return null;
 const day=new Date(ms).toISOString().slice(0,10);
 if(/^\d{4}-\d{2}-\d{2}$/.test(value)&&day!==value)return null;
 return day;
}
function entry(raw:Partial<Entry>,base:string):Entry|null {
 try {const title=cleanText(raw.title||'',300),url=canonicalUrl(raw.url||'',base);if(!title||!raw.url)return null;
 return {key:(raw.key||url).slice(0,2048),url,title,summary:cleanText(raw.summary||''),publishedAt:knownDate(raw.publishedAt),eventDate:knownDate(raw.eventDate),updatedAt:raw.updatedAt||null};}catch{return null;}
}
export function parseFeed(body:string,base:string):{method:'rss'|'atom';entries:Entry[]}|null {
 if(!/<(?:rss|feed|rdf:RDF)(?:\s|>)/i.test(body))return null;
 if(/<!DOCTYPE|<!ENTITY/i.test(body))throw new CollectionError('format','Feed contains unsupported XML declarations.');
 if(XMLValidator.validate(body)!==true)throw new CollectionError('format','Feed is incomplete or malformed.');
 const $=load(body,{xmlMode:true}),atom=$('feed').length>0;
 if(!(atom?/<\/feed>\s*$/i:/<\/(?:rss|rdf:RDF)>\s*$/i).test(body.trim()))throw new CollectionError('format','Feed is incomplete or malformed.');
 const entries:Entry[]=[];
 $(atom?'feed > entry':'item').slice(0,500).each((_,el)=>{
  const e=$(el),link=atom?e.find('link[rel="alternate"],link:not([rel])').first().attr('href'):e.find('link').first().text();
  const item=entry({key:e.find(atom?'id':'guid').first().text()||link,url:link,title:e.find('title').first().text(),summary:e.find(atom?'summary,content':'description').first().text(),publishedAt:e.find(atom?'published':'pubDate,dc\\:date').first().text(),eventDate:e.find('releaseDate,eventDate').first().text(),updatedAt:e.find('updated').first().text()||null},base);
  if(item)entries.push(item);
 });
 if(!entries.length&&$(atom?'entry':'item').length)throw new CollectionError('format','Feed entries are missing usable titles or links.');
 return {method:atom?'atom':'rss',entries};
}
export function discoverFeeds(body:string,base:string):string[] {
 const $=load(body),urls:string[]=[];
 $('link[rel="alternate"],a[href]').each((_,el)=>{const e=$(el),href=e.attr('href');if(href&&(/rss|atom/i.test(e.attr('type')||'')||(/\b(rss|atom)\b/i.test(e.text())&&/rss|atom|feed/i.test(href))))try{urls.push(canonicalUrl(href,base));}catch{}});
 return [...new Set(urls)].slice(0,2);
}
export function parsePage(body:string,base:string):Entry[] {
 const $=load(body),entries:Entry[]=[];
 $('script[type="application/ld+json"]').slice(0,30).each((_,el)=>{try{
  const queue:unknown[]=[JSON.parse($(el).text())];let count=0;
  while(queue.length&&++count<=300){const v=queue.shift();if(Array.isArray(v)){queue.push(...v.slice(0,100));continue;}if(!v||typeof v!=='object')continue;
   const o=v as Record<string,unknown>;for(const key of ['@graph','itemListElement','item'])if(o[key])queue.push(o[key]);
   const type=String(o['@type']||'');if(!/Article|BlogPosting|NewsArticle|Event|Product/.test(type))continue;
   const i=entry({url:typeof o.url==='string'?o.url:undefined,title:String(o.headline||o.name||''),summary:String(o.description||''),publishedAt:typeof o.datePublished==='string'?o.datePublished:null,eventDate:typeof (o.releaseDate||o.startDate)==='string'?String(o.releaseDate||o.startDate):null,updatedAt:typeof o.dateModified==='string'?o.dateModified:null},base);if(i)entries.push(i);
  }
 }catch{}});
 // JouwWeb's public news list exposes dates with each individual article.
 $('.jw-news-post, article').slice(0,150).each((_,el)=>{
  const e=$(el),a=e.find('h2 a,h3 a').first(),date=e.find('time,.jw-news-date').first();
  const i=entry({url:a.attr('href'),title:a.text(),summary:e.find('.jw-news-post__content,.entry-summary,.excerpt').first().text(),publishedAt:date.attr('datetime')||date.text()},base);if(i)entries.push(i);
 });
 // Calendar rows must contain an explicit date including a year; no guessed dates.
 $('table tr').slice(0,200).each((_,el)=>{const row=$(el),date=row.find('time').attr('datetime')||row.find('td').first().text().trim();if(!knownDate(date))return;row.find('a[href]').slice(0,8).each((_,a)=>{const i=entry({url:$(a).attr('href'),title:$(a).text(),eventDate:date},base);if(i)entries.push(i);});});
 return [...new Map(entries.map(e=>[e.url,e])).values()];
}
export function pageMetadata(body:string,url:string){
 const $=load(body);return entry({url,title:$('meta[property="og:title"]').attr('content')||$('h1').first().text()||$('title').text(),summary:$('meta[property="og:description"],meta[name="description"]').first().attr('content'),publishedAt:$('meta[property="article:published_time"]').attr('content')},url);
}
export function retained(entries:Entry[],now:Date){
 const cutoff=new Date(now.getTime()-14*86400000).toISOString().slice(0,10),today=now.toISOString().slice(0,10);
 return entries.filter(e=>!e.publishedAt||e.publishedAt>=cutoff||!!e.eventDate&&e.eventDate>=today).sort((a,b)=>(b.publishedAt||'').localeCompare(a.publishedAt||''));
}
export function robotsAllowed(body:string,url:string){
 const lines=body.split(/\r?\n/);let active=false;const rules:{allow:boolean;path:string}[]=[];
 for(const raw of lines){const line=raw.split('#')[0].trim(),match=line.match(/^(user-agent|allow|disallow)\s*:\s*(.*)$/i);if(!match)continue;
  if(match[1].toLowerCase()==='user-agent'){active=match[2]==='*'||/northsidecontentradar/i.test(match[2]);continue;}
  if(active&&match[2])rules.push({allow:match[1].toLowerCase()==='allow',path:match[2]});
 }
 const path=new URL(url).pathname+new URL(url).search;
 const matching=rules.filter(r=>{const regex=r.path.split('*').map(p=>p.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')).join('.*').replace(/\\\$$/,'$');return new RegExp('^'+regex).test(path);}).sort((a,b)=>b.path.length-a.path.length||Number(b.allow)-Number(a.allow));
 return matching[0]?.allow??true;
}
