import {identity, db, apiError} from '@/lib/storage';
import {campaignSaveSchema} from '@/lib/calendar-validation';

export async function GET() {
  try {
    await identity();
    const {data, error} = await (await db()).rpc('hub_team');
    if (error) throw error;
    const staff = (data as {id: string; data: {name: string; active: boolean}}[]).filter(x => x.data.active).map(x => ({id: x.id, name: x.data.name}));
    return Response.json({staff}, {headers: {'Cache-Control':'private, no-store'}});
  } catch(e) {return apiError(e);}
}
export async function POST(request: Request) {
  try {
    await identity(request);
    const raw = await request.text();
    if (Buffer.byteLength(raw) > 1400000) return Response.json({error:'Campaign is too large.'}, {status:413});
    let json;
    try {json = JSON.parse(raw);} catch {return Response.json({error:'Invalid JSON.'}, {status:400});}
    const parsed = campaignSaveSchema.safeParse(json);
    if (!parsed.success) return Response.json({error:parsed.error.issues[0]?.message || 'Check campaign fields.'}, {status:400});
    const {error} = await (await db()).rpc('hub_save_campaign', {p_payload:parsed.data});
    if (error) {
      if (error.code === '40001') return Response.json({error:'Someone changed this campaign or its posts. Close this preview, refresh the calendar, and review again.'}, {status:409});
      if (error.code === '22023') return Response.json({error:error.message}, {status:400});
      throw error;
    }
    return Response.json({ok:true}, {headers:{'Cache-Control':'no-store'}});
  } catch(e) {return apiError(e);}
}
