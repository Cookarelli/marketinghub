'use client';
import Link from 'next/link';
export default function ErrorPage({reset}:{reset:()=>void}){return <main className="workspace"><section className="panel"><h1>Content Radar is unavailable</h1><p>Please retry. Saved content remains in your workspace.</p><button onClick={reset}>Try again</button><p><Link href="/">Back to Marketing Hub</Link></p></section></main>;}
