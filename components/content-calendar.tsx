'use client';

import {useRef, useState} from 'react';
import {CalendarDays, Download, Pencil, Plus} from 'lucide-react';
import {toast} from 'sonner';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {clientId} from '@/lib/client-id';
import {PLATFORMS} from '@/lib/marketing';
import {calendarDay, calendarTime, nextTuesday, type CalendarPost, type CalendarPostData} from '@/lib/content-calendar';

type Props = {posts: CalendarPost[]; busy: boolean; loading: boolean; onSave: (id: string, data: CalendarPostData) => Promise<boolean>};
const emptyDraft: CalendarPostData = {title: '', date: '', timezone: 'America/Chicago', source: 'tbd', caption: '', status: 'draft', category: 'Topical'};
const categories = ['Topical', 'Release', 'Brand / educational'] as const;

function exportCalendar(posts: CalendarPost[]) {
  const rows = [['Date / recurrence', 'Time (Central)', 'Category', 'Title', 'Platform', 'Status', 'Caption and production notes', 'References'],
    ...posts.map(({data: p}) => [p.recurrence ? 'Every Tuesday' : p.date.slice(0, 10), calendarTime(p.date), p.category || '', p.title, p.source === 'tbd' ? 'To confirm' : p.source, p.status, p.caption, (p.references || []).join('\n')])];
  const csv = rows.map(row => row.map(value => {
    const text = /^[=+@\-]/.test(value) ? "'" + value : value;
    return '"' + text.replace(/"/g, '""') + '"';
  }).join(',')).join('\r\n');
  const url = URL.createObjectURL(new Blob(['\ufeff' + csv], {type: 'text/csv;charset=utf-8'}));
  const a = document.createElement('a'); a.href = url; a.download = 'northside-content-calendar.csv'; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function ContentCalendar({posts, busy, loading, onSave}: Props) {
  const [draft, setDraft] = useState<CalendarPostData>(emptyDraft);
  const [editingId, setEditingId] = useState<string | null>(null);
  const formRef = useRef<HTMLFormElement>(null);
  const titleRef = useRef<HTMLInputElement>(null);
  const dated = posts.filter(p => !p.data.recurrence).sort((a, b) => a.data.date.localeCompare(b.data.date));
  const recurring = posts.filter(p => p.data.recurrence).sort((a, b) => a.data.date.slice(11).localeCompare(b.data.date.slice(11)));
  const days = [...new Set(dated.map(p => p.data.date.slice(0, 10)))];

  function openDraft(post?: CalendarPost, occurrence = false) {
    setEditingId(post && !occurrence ? post.id : null);
    setDraft(post ? {...post.data, ...(occurrence ? {recurrence: undefined, date: nextTuesday(post.data.date.slice(11, 16)), status: 'draft'} : {})} : {...emptyDraft});
    formRef.current?.scrollIntoView({behavior: 'smooth', block: 'start'});
    titleRef.current?.focus({preventScroll: true});
  }

  function card(post: CalendarPost) {
    const p = post.data;
    const radar = post.id.startsWith('radar_');
    return <article className="panel calendar-card" key={post.id}>
      <div className="calendar-card-top"><time dateTime={p.date}>{calendarTime(p.date)}</time><span className="tag">{p.category || 'Content'}</span></div>
      <h3>{p.title}</h3>
      <p className="muted">{p.source === 'tbd' ? 'Platform to confirm' : p.source} · {p.status}</p>
      {p.caption ? <details><summary>Caption &amp; production notes</summary><p className="calendar-notes">{p.caption}</p>
        {p.references?.length ? <ul className="calendar-references">{p.references.map((url, i) => <li key={url}><a href={url} target="_blank" rel="noreferrer">Source {i + 1}<span className="sr-only"> for {p.title}</span></a></li>)}</ul> : null}
      </details> : null}
      <div className="calendar-card-actions">{radar ? <Button variant="outline" asChild><a href="/content-radar/editorial">Open editorial review</a></Button> : <>
        <Button variant="outline" disabled={busy} onClick={() => openDraft(post)}><Pencil size={18}/>{p.recurrence ? 'Edit series' : 'Edit draft'}</Button>
        {p.recurrence ? <Button variant="outline" disabled={busy} onClick={() => openDraft(post, true)}><Plus size={18}/>Create next draft</Button> :
          <label className="calendar-status"><span className="sr-only">Status for {p.title}</span><select value={p.status} disabled={busy} onChange={e => void onSave(post.id, {...p, status: e.target.value})}>
            {['draft', 'review', 'approved', 'published'].map(s => <option value={s} key={s}>{s}</option>)}
          </select></label>}
      </>}</div>
    </article>;
  }

  return <>
    <div className="section-title"><div><p className="eyebrow">THE CONTENT CALENDAR</p><h2>Three posts. One clear plan.</h2><p className="muted">All times are Central (America/Chicago). Drafts stay here until you publish them on each platform.</p></div>
      <div className="button-row"><Button variant="outline" disabled={loading || !posts.length} onClick={() => exportCalendar([...dated, ...recurring])}><Download size={18}/>Export calendar</Button><Button onClick={() => openDraft()}><Plus size={18}/>New draft</Button></div>
    </div>
    {loading ? <p role="status" className="notice">Loading the calendar…</p> : null}
    {!loading && !dated.length ? <p className="panel">No dated drafts yet. Add your first post below.</p> : null}
    <div className="calendar-days">{days.map(day => <section key={day} aria-label={calendarDay(day)}>
      <div className="calendar-day-heading"><CalendarDays aria-hidden="true"/><h3>{calendarDay(day)}</h3><span className="tag">{dated.filter(p => p.data.date.startsWith(day)).length} posts</span></div>
      <div className="calendar-post-grid">{dated.filter(p => p.data.date.startsWith(day)).map(card)}</div>
    </section>)}</div>
    {recurring.length ? <section className="calendar-recurring" aria-labelledby="weekly-series"><p className="eyebrow">REPEAT EACH WEEK</p><h2 id="weekly-series">Every Tuesday</h2><p className="muted">Use each series to prepare its next dated draft. Publishing remains manual.</p><div className="calendar-post-grid">{recurring.map(card)}</div></section> : null}
    <form ref={formRef} className="panel calendar-form" onSubmit={async e => {
      e.preventDefault();
      if (!draft.title.trim() || !draft.date) return toast.error('Add a title and date.');
      if (draft.recurrence && new Date(draft.date.slice(0, 10) + 'T12:00:00Z').getUTCDay() !== 2) return toast.error('Choose a Tuesday for this weekly series.');
      const ok = await onSave(editingId || clientId(), {...draft, title: draft.title.trim(), timezone: 'America/Chicago'});
      if (ok) { setDraft({...emptyDraft}); setEditingId(null); }
    }}>
      <h3>{editingId ? draft.recurrence ? 'Edit Tuesday series' : 'Edit dated draft' : 'Create a dated draft'}</h3>
      <label className="field"><span>Title</span><Input ref={titleRef} required value={draft.title} onChange={e => setDraft({...draft, title: e.target.value})}/></label>
      <div className="two-fields"><label className="field"><span>{draft.recurrence ? 'First Tuesday and time (Central)' : 'Publish date and time (Central)'}</span><Input required type="datetime-local" value={draft.date} onChange={e => setDraft({...draft, date: e.target.value})}/></label>
        <label className="field"><span>Platform</span><select value={draft.source} onChange={e => setDraft({...draft, source: e.target.value})}><option value="tbd">To confirm</option>{[...PLATFORMS, 'email'].map(p => <option key={p} value={p}>{p}</option>)}</select></label></div>
      <label className="field"><span>Content type</span><select value={draft.category || 'Topical'} onChange={e => setDraft({...draft, category: e.target.value as CalendarPostData['category']})}>{categories.map(c => <option key={c}>{c}</option>)}</select></label>
      <label className="field"><span>Caption and production notes</span><Textarea rows={6} value={draft.caption} onChange={e => setDraft({...draft, caption: e.target.value})}/></label>
      <div className="button-row"><Button disabled={busy} type="submit">{busy ? 'Saving…' : editingId ? 'Save changes' : 'Save draft'}</Button>{editingId ? <Button type="button" variant="outline" onClick={() => {setEditingId(null); setDraft({...emptyDraft});}}>Cancel edit</Button> : null}</div>
    </form>
  </>;
}
