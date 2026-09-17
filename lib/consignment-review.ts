import type {CalendarPostData} from './content-calendar';
import type {Campaign} from './consignment';

export type LotResult = {url: string; outcome: 'unknown' | 'sold' | 'unsold' | 'withdrawn'; price?: number; currency?: string};
export type CampaignVerification = {
  closing?: string;
  lotLinksChecked?: boolean;
  results?: LotResult[];
  resultsChecked?: boolean;
  reviewedCaption?: string;
  // Snapshot binds a staff attestation to the auction facts actually reviewed.
  auction?: {closing: string; batchUrl: string; cards: Campaign['cards']};
};
export function auctionFacts(c: Campaign) {return {closing:c.closing, batchUrl:c.batchUrl, cards:c.cards};}
function factKey(f: CampaignVerification['auction']) {return f ? JSON.stringify([f.closing,f.batchUrl,f.cards.map(c=>[c.name,c.url])]) : ''; }
export function approvalIssues(p: CalendarPostData, c?: Campaign): string[] {
  if (!p.consignment) return [];
  const issues: string[] = [], v = p.verification, stage = p.consignment.stage;
  if (!(p.assets || []).some(a => a.trim())) issues.push('Add the finished creative / asset reference.');
  if (stage === 'midweek' && !p.staffPicks?.trim()) issues.push('Record staff picks.');
  for (const task of p.tasks || []) if (task.trim() && !p.completedTasks?.includes(task)) issues.push(task);
  if (stage !== 'closing' && stage !== 'recap') return issues;
  if (!c || factKey(v?.auction) !== factKey(auctionFacts(c))) issues.push('Verify the current auction details.');
  if (!p.caption.trim() || v?.reviewedCaption !== p.caption || /\[(verify|insert)/i.test(p.caption)) issues.push('Review the final caption against verified auction facts; remove drafting placeholders.');
  const urls = c?.cards.map(card => card.url) || [];
  if (!urls.length || urls.some(url => !p.references?.includes(url))) issues.push('Include every featured direct lot link.');
  if (stage === 'closing') {
    if (!v?.closing || v.closing !== c?.closing) issues.push('Verify the exact closing deadline (America/Chicago).');
    if (!v?.lotLinksChecked) issues.push('Verify that the direct lot links open the correct listings.');
    if (c && (p.date.slice(0,10) !== c.closing.slice(0,10) || p.date > c.closing)) issues.push('Schedule the closing-day post on closing day, at or before the deadline.');
  } else {
    if (!v?.resultsChecked || urls.some(url => !v.results?.some(r => r.url === url && r.outcome !== 'unknown'))) issues.push('Verify the outcome of every featured lot, including unsold lots.');
    if (v?.results?.some(r => r.outcome !== 'sold' && r.price !== undefined)) issues.push('Only sold lots may have a sale price.');
    if (c && p.date <= c.closing) issues.push('Schedule the results recap after closing.');
  }
  return [...new Set(issues)];
}
export function verifiedRecap(c: Campaign, results: LotResult[]) {
  const lines = c.cards.map(card => {
    const r = results.find(x => x.url === card.url);
    if (!r || r.outcome === 'unknown') throw new Error('Verify every lot outcome before preparing the recap.');
    if (r.outcome === 'sold') return `${card.name}: sold${r.price === undefined ? '' : ` for ${r.currency || 'USD'} ${r.price.toFixed(2)}`}. ${card.url}`;
    return `${card.name}: ${r.outcome === 'unsold' ? 'unsold' : 'withdrawn'}. ${card.url}`;
  });
  return `${c.name} — verified results\n${lines.join('\n')}\nHave cards for a future auction? Submit your consignments.`;
}
export function invalidateApproval(p: CalendarPostData): CalendarPostData {
  return {...p, verification: p.verification ? {...p.verification,auction:undefined,lotLinksChecked:false,resultsChecked:false,reviewedCaption:undefined} : undefined, status:p.status === 'approved' ? 'review' : p.status};
}
