'use client';

import {useSyncExternalStore} from 'react';
import {ThemeProvider as NextThemeProvider, useTheme} from 'next-themes';
import {Moon} from 'lucide-react';

const subscribe = () => () => {};
const clientSnapshot = () => true;
const serverSnapshot = () => false;

function ThemeToggle() {
  const {resolvedTheme, setTheme} = useTheme();
  const mounted = useSyncExternalStore(subscribe, clientSnapshot, serverSnapshot);
  const dark = mounted && resolvedTheme === 'dark';
  return <div className="appearance-bar">
    <button className="theme-toggle" type="button" role="switch" aria-label="Dark mode"
      aria-checked={dark} disabled={!mounted} onClick={() => setTheme(dark ? 'light' : 'dark')}>
      <Moon size={20} aria-hidden="true"/><span>Dark mode</span><span className="theme-state">{dark ? 'On' : 'Off'}</span>
    </button>
  </div>;
}

export function ThemeProvider({children}: {children: React.ReactNode}) {
  return <NextThemeProvider attribute="class" defaultTheme="system" enableSystem
    storageKey="northside-color-theme" disableTransitionOnChange>
    <ThemeToggle/>{children}
  </NextThemeProvider>;
}
