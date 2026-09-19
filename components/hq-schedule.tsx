'use client';
import Link from 'next/link';
import {useEffect,useState} from 'react';
import {Input} from '@/components/ui/input';
import {chicagoWall} from '@/lib/consignment';
import {calendarDay,calendarTime} from '@/lib/content-calendar';
import {approvalCurrent,productionStatuses,type Deliverable,type HqRecord,type Project} from '@/lib/hq-model';

export function HqSchedule({records,projects,today=false}:{records:HqRecord<Deliverable>[];projects:HqRecord<Project>[];today?:boolean}) {
  const [day,setDay]=useState(''),[date,setDate]=useState('');
  useEffect(()=>{const tick=()=>setDay(chicagoWall(Date.now()).slice(0,10));tick();const timer=window.setInterval(tick,60000);return()=>window.clearInterval(timer);},[]);
  const events=records.flatMap(r=>{
    const d=r.data,p=projects.find(p=>p.id===d.projectId)?.data;
    const rows:{id:string;title:string;date:string;label:string;state:string;attention:boolean}[]=[];
    if(d.productionDue)rows.push({id:r.id,title:d.title,date:d.productionDue,label:'Production deadline',state:productionStatuses[d.status],attention:d.status==='needs_review'||d.blocked||(d.productionDue.slice(0,10)<=day&&!['ready','done'].includes(d.status))});
    for(const [platform,publication] of Object.entries(d.publications)) {
      const at=publication.publishedAt||publication.scheduledFor||d.publishAt;
      if(at)rows.push({id:r.id,title:d.title,date:at,label:platform+' · '+(publication.status==='planned'?'Intended publication':publication.status==='scheduled'?'Confirmed schedule':'Actual publication'),state:publication.status,attention:publication.status!=='published'&&at.slice(0,10)<=day&&approvalCurrent(d,p)});
    }
    return rows;
  }).sort((a,b)=>a.date.localeCompare(b.date));
  const shown=events.filter(row=>today?(row.date.slice(0,10)===day||row.attention):(!date||row.date.slice(0,10)===date));
  const undated=records.filter(r=>!r.data.productionDue||r.data.blocked||r.data.status==='needs_review');
  return <section className="panel"><div className="section-title"><div><h2>{today?'HQ work needing attention':'Project production and publishing'}</h2><p className="muted">America/Chicago · Each destination keeps its own publishing state.</p></div><Link href="/projects">Open projects →</Link></div>
    {!today&&<label className="field"><span>Filter HQ schedule by date (leave blank for all)</span><Input type="date" value={date} onChange={e=>setDate(e.target.value)}/></label>}
    <ul className="hq-deliverables">{shown.map((row,index)=><li key={row.id+row.label+index}><div><Link href={'/projects/work/'+row.id}>{row.title}</Link><p className="muted">{row.label} · {calendarDay(row.date)} · {calendarTime(row.date)}</p></div><span className="tag">{row.state}</span></li>)}</ul>
    {!shown.length&&<p className="muted">{today?'No dated HQ work needs attention right now.':'No HQ dates match this view.'}</p>}
    {undated.length>0&&<details className="hq-details"><summary>Missing deadlines, blocked work and reviews ({undated.length})</summary><ul className="hq-deliverables">{undated.map(r=><li key={r.id}><Link href={'/projects/work/'+r.id}>{r.data.title}</Link><span>{r.data.blocked?'Blocked':r.data.status==='needs_review'?'Needs review':'Deadline missing'}</span></li>)}</ul></details>}
  </section>;
}
