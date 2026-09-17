'use client';
import type {CalendarPostData} from '@/lib/content-calendar';
import type {Campaign} from '@/lib/consignment';
import {approvalIssues, auctionFacts, verifiedRecap} from '@/lib/consignment-review';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';

export function OutstandingTasks({data,campaign}:{data:CalendarPostData;campaign?:Campaign}) {
  const issues=approvalIssues(data,campaign);
  return issues.length ? <div className="notice production-outstanding"><strong>Outstanding production tasks ({issues.length})</strong><ul>{issues.map(task=><li key={task}>{task}</li>)}</ul></div> : <p className="notice">Production checks complete. Publishing remains manual.</p>;
}
export function ConsignmentReview({data,campaign,onChange}:{data:CalendarPostData;campaign?:Campaign;onChange:(data:CalendarPostData)=>void}) {
  if(!data.consignment)return null;
  const v=data.verification || {}, stage=data.consignment.stage;
  const update=(patch:Partial<NonNullable<CalendarPostData['verification']>>)=>onChange({...data,verification:{...v,...patch}});
  return <div className="campaign-fields">
    <OutstandingTasks data={data} campaign={campaign}/>
    <fieldset><legend>Completed production work</legend>{(data.tasks || []).filter(task=>task.trim()).map((task,i)=><label className="check-field" key={i}><input type="checkbox" checked={data.completedTasks?.includes(task) || false} onChange={e=>onChange({...data,completedTasks:e.target.checked ? [...new Set([...(data.completedTasks || []),task])] : data.completedTasks?.filter(t=>t!==task)})}/><span>{task}</span></label>)}</fieldset>
    {stage==='midweek' && <label className="field"><span>Staff picks and why</span><Textarea value={data.staffPicks || ''} onChange={e=>onChange({...data,staffPicks:e.target.value})}/></label>}
    {campaign && (stage==='closing'||stage==='recap') && <fieldset className="campaign-fields"><legend>Required verification before approval</legend>
      <p>Check the auction platform directly. These are staff confirmations, not automatic verification.</p>
      {stage==='closing' && <>
        <p>Current closing deadline: <strong>{campaign.closing.replace('T',' ')} CT (America/Chicago)</strong></p>
        <label className="check-field"><input type="checkbox" checked={v.closing===campaign.closing} onChange={e=>update({closing:e.target.checked?campaign.closing:undefined,auction:auctionFacts(campaign),reviewedCaption:undefined})}/><span>I verified this exact closing deadline on the auction platform.</span></label>
        <label className="check-field"><input type="checkbox" checked={v.lotLinksChecked || false} onChange={e=>update({lotLinksChecked:e.target.checked,auction:auctionFacts(campaign),reviewedCaption:undefined})}/><span>I opened and verified every featured direct lot link.</span></label>
      </>}
      {stage==='recap' && <>
        <p>Record every featured lot as sold, unsold, or withdrawn. Leave prices blank unless verified. Never infer a sale from an ended listing.</p>
        {campaign.cards.map(card=>{
          const result=v.results?.find(r=>r.url===card.url) || {url:card.url,outcome:'unknown' as const};
          const change=(patch:Partial<typeof result>)=>update({results:[...(v.results||[]).filter(r=>r.url!==card.url),{...result,...patch}],resultsChecked:false,reviewedCaption:undefined,auction:auctionFacts(campaign)});
          return <div className="panel campaign-fields" key={card.url}><a href={card.url} target="_blank" rel="noreferrer">{card.name} — direct lot</a>
            <label className="field"><span>Outcome for {card.name}</span><select value={result.outcome} onChange={e=>change({outcome:e.target.value as typeof result.outcome,price:undefined,currency:undefined})}>{['unknown','sold','unsold','withdrawn'].map(value=><option key={value}>{value}</option>)}</select></label>
            {result.outcome==='sold' && <div className="two-fields"><label className="field"><span>Verified sale price for {card.name} (optional)</span><Input type="number" min="0.01" step="0.01" value={result.price ?? ''} onChange={e=>change({price:e.target.value===''?undefined:Number(e.target.value),currency:result.currency || 'USD'})}/></label><label className="field"><span>Currency for {card.name}</span><Input maxLength={3} value={result.currency || 'USD'} onChange={e=>change({currency:e.target.value.toUpperCase()})}/></label></div>}
          </div>;
        })}
        <label className="check-field"><input type="checkbox" checked={v.resultsChecked || false} onChange={e=>update({resultsChecked:e.target.checked,auction:auctionFacts(campaign),reviewedCaption:undefined})}/><span>I verified every lot outcome and any entered sale price against final auction results.</span></label>
        <Button type="button" variant="outline" disabled={!v.resultsChecked || campaign.cards.some(card=>!v.results?.some(r=>r.url===card.url && r.outcome!=='unknown'))} onClick={()=>onChange({...data,caption:verifiedRecap(campaign,v.results || []),verification:{...v,reviewedCaption:undefined}})}>Use verified results in caption</Button>
      </>}
      <label className="check-field"><input type="checkbox" checked={!!data.caption.trim() && v.reviewedCaption===data.caption} onChange={e=>update({reviewedCaption:e.target.checked?data.caption:undefined,auction:auctionFacts(campaign)})}/><span>I checked the final caption against these facts, including sold versus unsold outcomes and any prices. No placeholders or invented claims remain.</span></label>
    </fieldset>}
  </div>;
}
