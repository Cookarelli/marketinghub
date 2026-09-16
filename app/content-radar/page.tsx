import {redirect} from 'next/navigation';
import {requireRadarStaff} from '@/lib/content-radar/server';
import Radar from './radar';
export const dynamic='force-dynamic';
export default async function Page(){let staff;try{staff=await requireRadarStaff();}catch{redirect('/login');}return <Radar organization={staff.orgName}/>;}
