import {fetchUrl} from './urls.ts';
export class CollectionError extends Error {
 code:string;retryAfter:number;
 constructor(code:string,message:string,retryAfter=300){super(message);this.code=code;this.retryAfter=retryAfter;}
}
export type DocumentResult={url:string;body:string;status:number;etag:string|null;modified:string|null};
export type Reader=(url:string,validators?:{etag?:string|null;modified?:string|null})=>Promise<DocumentResult>;
export function createReader(source:string,options:{transport?:typeof fetch;deadline?:number;maxRequests?:number}={}):Reader {
 const transport=options.transport||fetch,deadline=options.deadline||Date.now()+24000;
 let calls=0,lastRequest=0;
 return async(value,validators={})=>{
  let url=fetchUrl(value,source);
  for(let redirects=0,retries=0;;){
   if(++calls>(options.maxRequests||8)||Date.now()>deadline-500)throw new CollectionError('budget','Collection time limit reached. Try again later.');
   const delay=Math.max(0,300-(Date.now()-lastRequest));if(delay)await new Promise(r=>setTimeout(r,delay));
   const signal=AbortSignal.timeout(Math.max(1,Math.min(6000,deadline-Date.now())));
   let response:Response;
   try{lastRequest=Date.now();response=await transport(url,{redirect:'manual',signal,headers:{'User-Agent':'NorthsideContentRadar/1.0','Accept':'application/rss+xml, application/atom+xml, application/xml, text/html, text/plain;q=0.5',...(validators.etag?{'If-None-Match':validators.etag}:{}),...(validators.modified?{'If-Modified-Since':validators.modified}:{})}});}catch{
    if(retries++<1&&Date.now()<deadline-1500)continue;
    throw new CollectionError('network','Publisher request timed out or could not connect.');
   }
   if([301,302,303,307,308].includes(response.status)){
    await response.body?.cancel();const location=response.headers.get('location');
    if(!location||++redirects>3)throw new CollectionError('redirect','Publisher returned an invalid redirect.');
    try{url=fetchUrl(new URL(location,url).href,source);}catch{throw new CollectionError('blocked','Publisher redirected outside its approved domain. Open it manually.');}
    continue;
   }
   if(response.status===429||response.status>=500){
    await response.body?.cancel();const raw=response.headers.get('retry-after');
    const seconds=raw?(/^\d+$/.test(raw)?Number(raw):Math.ceil((Date.parse(raw)-Date.now())/1000)):60;
    if(response.status!==429&&retries++<1&&Date.now()<deadline-2000){await new Promise(r=>setTimeout(r,500));continue;}
    throw new CollectionError('rate-limit',`Publisher returned HTTP ${response.status}. Collection will retry later.`,Math.max(60,Math.min(86400,Number.isFinite(seconds)?seconds:300)));
   }
   if(response.status===304)return {url,body:'',status:304,etag:response.headers.get('etag'),modified:response.headers.get('last-modified')};
   if(!response.ok){await response.body?.cancel();throw new CollectionError([401,403].includes(response.status)?'blocked':'http',`Publisher returned HTTP ${response.status}. Manual links remain available.`,response.status===403?3600:300);}
   const contentType=response.headers.get('content-type')||'';
   if(!/xml|html|text\/plain/i.test(contentType)){await response.body?.cancel();throw new CollectionError('format','Publisher did not return a supported page or feed.');}
   const reader=response.body?.getReader();if(!reader)throw new CollectionError('empty','Publisher returned an empty response.');
   const decoder=new TextDecoder();let size=0,body='';
   try{while(true){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;if(size>1500000){await reader.cancel();throw new CollectionError('size','Publisher response exceeds the collection size limit.');}body+=decoder.decode(value,{stream:true});}body+=decoder.decode();}catch(e){if(e instanceof CollectionError)throw e;throw new CollectionError('network','Publisher response was interrupted.');}
   return {url,body,status:response.status,etag:response.headers.get('etag'),modified:response.headers.get('last-modified')};
  }
 };
}
