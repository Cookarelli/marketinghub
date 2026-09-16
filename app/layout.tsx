import type { Metadata } from "next";
import "./globals.css";
import {ThemeProvider} from '@/components/theme-provider';

export const metadata: Metadata = {
  title: "Northside Marketing Hub",
  description: "Launch planning, content production and campaign measurement for Northside Collectibles.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased"><ThemeProvider>{children}</ThemeProvider></body>
    </html>
  );
}
