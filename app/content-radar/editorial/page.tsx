import {redirect} from 'next/navigation';
import {requireRadarStaff} from '@/lib/content-radar/server';
import Editorial from './editorial';
export const dynamic='force-dynamic';
export default async function Page(){try{await requireRadarStaff();}catch{redirect('/login');}return <Editorial/>;}
