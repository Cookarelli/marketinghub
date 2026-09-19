'use client';

import {useEffect, useState} from 'react';
import Link from 'next/link';
import {ArrowUpRight, CalendarDays, ClipboardCheck, Send} from 'lucide-react';
import {todayWork} from '@/lib/hq-today';
import {calendarDay, calendarTime, type CalendarPost} from '@/lib/content-calendar';

export function HqToday({posts, loading, failed}: {posts: CalendarPost[]; loading: boolean; failed: boolean}) {
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    const update = () => setNow(Date.now());
    update();
    const timer = window.setInterval(update, 60000);
    return () => window.clearInterval(timer);
  }, []);
  if (failed) return <p className="panel">Today’s work is unavailable until the workspace reconnects. Use Retry above to load your saved records.</p>;
  if (loading || now === null) return <p className="panel" role="status">Preparing today’s work…</p>;
  const work = todayWork(posts, now);
  return <>
    <div className="hq-today-intro"><p className="eyebrow">{calendarDay(work.day)}</p><h2>Keep the work moving.</h2><p className="muted">Review what’s scheduled, finish production and publish through your usual channels.</p></div>
    <div className="hq-stats">
      {[{label: 'On today’s calendar', count: work.scheduled.length, icon: CalendarDays}, {label: 'Calendar posts in review', count: work.review.length, icon: ClipboardCheck}, {label: 'Approved posts due', count: work.ready.length, icon: Send}].map(({label, count, icon: Icon}) => <Link className="hq-stat" href="/calendar" key={label}><Icon size={24} aria-hidden="true"/><strong>{count}</strong><span>{label}</span><ArrowUpRight size={18} aria-hidden="true"/></Link>)}
    </div>
    <div className="hq-columns">
      <section className="panel"><div className="section-title"><h2>Today’s schedule</h2><Link href="/calendar">Open calendar</Link></div>
        {work.scheduled.length ? <ul className="hq-work-list">{work.scheduled.map(post => <li key={post.id}><time dateTime={post.data.date}>{calendarTime(post.data.date)}</time><div><Link href="/calendar">{post.data.title}</Link><p className="muted">{post.data.platforms?.join(', ') || (post.data.source === 'tbd' ? 'Platform to confirm' : post.data.source)}</p></div><span className="tag">{post.data.status}</span></li>)}</ul> : <div className="hq-empty"><h3>No dated posts scheduled today</h3><p>Open the calendar to prepare a draft or use a weekly series.</p><Link href="/calendar">Plan the next post <ArrowUpRight size={16} aria-hidden="true"/></Link></div>}
      </section>
      <section className="panel"><div className="section-title"><h2>Needs attention</h2></div>
        <Link className="hq-action-row" href="/requests"><div><strong>Requests & review</strong><p className="muted">Ask for work, see decisions and open editorial review.</p></div><ArrowUpRight aria-hidden="true"/></Link>
        <Link className="hq-action-row" href="/calendar"><div><strong>{work.overdue.length} past-due drafts</strong><p className="muted">Review dates before approving or publishing.</p></div><ArrowUpRight aria-hidden="true"/></Link>
        <Link className="hq-action-row" href="/assets"><div><strong>Prepare the next asset</strong><p className="muted">Upload media or continue a saved editing job.</p></div><ArrowUpRight aria-hidden="true"/></Link>
      </section>
    </div>
  </>;
}
