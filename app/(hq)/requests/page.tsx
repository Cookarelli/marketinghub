import Editorial from '@/app/content-radar/editorial/editorial';
export const metadata = {title: 'Requests | Northside HQ'};
export default async function Page({searchParams}: {searchParams: Promise<{view?: string}>}) {
  const {view} = await searchParams;
  return <Editorial key={view || 'queue'} initialTab={view === 'staff' ? 'Staff' : 'Editorial queue'}/>;
}
