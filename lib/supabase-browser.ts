import { createBrowserClient } from '@supabase/ssr';

export function browserClient(manualRecovery = false) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Team sign in has not been configured yet.');
  return createBrowserClient(url, key, manualRecovery ? {
    isSingleton: false,
    auth: { detectSessionInUrl: false },
  } : undefined);
}
