'use client';
import {createBrowserClient} from '@supabase/ssr';
export function SignOut(){return <button className="signout" onClick={async()=>{const client=createBrowserClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!);await client.auth.signOut();window.location.assign('/login');}}>Sign out</button>;}
