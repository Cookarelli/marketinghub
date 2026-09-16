'use client';
import {useState} from 'react';
import {createBrowserClient} from '@supabase/ssr';
export default function Login() {
  const [email,setEmail]=useState(''),[password,setPassword]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false);
  async function submit(e:React.FormEvent) {
    e.preventDefault();setError('');setBusy(true);
    try {
      if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) throw new Error('Team sign in has not been configured yet.');
      const client=createBrowserClient(process.env.NEXT_PUBLIC_SUPABASE_URL,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
      const result=await client.auth.signInWithPassword({email:email.trim(),password});
      if (result.error) throw new Error('Sign in failed. Check your email and password.');
      const check=await fetch('/api/records');
      if (!check.ok) {await client.auth.signOut();throw new Error('This account could not open the Northside workspace. Contact Steven.');}
      window.location.assign('/');
    } catch(e) {setError((e as Error).message);} finally {setBusy(false);}
  }
  return <main className="auth-shell"><section className="panel"><p className="brand-word">NORTHSIDE MARKETING</p><h1>Welcome back</h1><p>Sign in to the shared team workspace.</p><form onSubmit={submit}><label htmlFor="email">Email address</label><input id="email" autoComplete="username" type="email" required value={email} onChange={e=>setEmail(e.target.value)}/><label htmlFor="password">Password</label><input id="password" autoComplete="current-password" type="password" required value={password} onChange={e=>setPassword(e.target.value)}/>{error&&<p role="alert">{error}</p>}<button disabled={busy}>{busy?'Signing in…':'Sign in'}</button></form><p className="muted">Need access or a password reset? Contact Steven.</p></section></main>;
}
