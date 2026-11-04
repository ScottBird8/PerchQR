// Looks up a listing by MLS number from the calling agent's own connected
// MLS (via the Spark API) and returns it mapped to this site's property
// fields, with photos already downloaded and re-hosted in our own Storage
// bucket (so the site never depends on Spark's CDN staying up).
//
// Multi-tenant descendant of the single-tenant version at
// C:\Users\scott\Scotts QR\supabase\functions\mls-lookup\index.ts. That
// version read one Spark token from a project-wide secret (SPARK_ACCESS_TOKEN)
// — this one looks up the CALLING AGENT's own token from `mls_credentials`
// (set via the admin's "Connect MLS" tab), since every beta agent brings
// their own free per-agent Spark access token. See PLANNING.md "RESOLVED:
// MLS credential model is per-agent, not shared."
//
// Requires one secret on this function (Project Settings -> Edge Functions ->
// Secrets): SUPABASE_SERVICE_ROLE_KEY is usually already available by default
// in Supabase Edge Functions; only add manually if missing.
//
// Only callable by a signed-in agent (verifies the caller's Supabase Auth
// session) — never public, and only ever touches that same agent's own
// mls_credentials row (enforced here in code, not just RLS, since this
// function runs with the service role and RLS doesn't apply to it).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Spark hosts + the OIDC key (same secrets as the spark-oidc function; only
// needed for agents who connected with "Connect your Flexmls account").
const AUTH_BASE = (Deno.env.get('SPARK_AUTH_BASE') || 'https://sparkplatform.com').replace(/\/$/, '');
const API_BASE = (Deno.env.get('SPARK_API_BASE') || 'https://replication.sparkapi.com').replace(/\/$/, '');
const OIDC_CLIENT_ID = Deno.env.get('SPARK_OIDC_CLIENT_ID') || '';
const OIDC_CLIENT_SECRET = Deno.env.get('SPARK_OIDC_CLIENT_SECRET') || '';

// An OIDC agent's access token (they last 24h). Returns a still-valid one,
// refreshing it first when it's within 5 minutes of expiring (Spark rotates
// the refresh token on every refresh, so the new one is saved right away).
// Returns null when there's no usable connection — the agent must reconnect.
async function getOidcAccessToken(admin: any, agentId: string): Promise<string | null> {
  const { data: row } = await admin
    .from('spark_oidc_tokens')
    .select('access_token, refresh_token, expires_at')
    .eq('agent_id', agentId)
    .maybeSingle();
  if (!row) return null;
  const expiresMs = row.expires_at ? new Date(row.expires_at).getTime() : 0;
  if (expiresMs - Date.now() > 5 * 60 * 1000) return row.access_token;
  if (!row.refresh_token || !OIDC_CLIENT_ID || !OIDC_CLIENT_SECRET) return null;

  const res = await fetch(`${AUTH_BASE}/openid/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({
      client_id: OIDC_CLIENT_ID,
      client_secret: OIDC_CLIENT_SECRET,
      grant_type: 'refresh_token',
      refresh_token: row.refresh_token,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body?.access_token) return null;
  await admin.from('spark_oidc_tokens').update({
    access_token: body.access_token,
    refresh_token: body.refresh_token || row.refresh_token,
    expires_at: new Date(Date.now() + (Number(body.expires_in) || 86400) * 1000).toISOString(),
    updated_at: new Date().toISOString(),
  }).eq('agent_id', agentId);
  return body.access_token;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function money(n: number | null | undefined): string {
  if (n == null) return '';
  return '$' + Math.round(n).toLocaleString('en-US');
}

function mapStatus(standardStatus: string | null, mlsStatus: string | null): string {
  const s = (standardStatus || mlsStatus || '').toLowerCase();
  if (s.includes('pending') || s.includes('under contract')) return 'Pending';
  if (s.includes('closed') || s.includes('sold')) return 'Sold';
  return 'Active';
}

function mapType(propertyType: string | null, propertySubType: string | null): string {
  const s = ((propertyType || '') + ' ' + (propertySubType || '')).toLowerCase();
  if (s.includes('land') || s.includes('farm') || s.includes('lot')) return 'land';
  if (s.includes('commercial') || s.includes('business')) return 'business';
  return 'residential';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });

  try {
    const authHeader = req.headers.get('Authorization') || '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '');
    if (!jwt) return json({ error: 'Not authenticated' }, 401);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: 'Not authenticated' }, 401);
    const agentId = userData.user.id;

    // Respect the account's status (pending/paused/suspended/canceled/archived
    // accounts can't use the dashboard). If the account-management tables
    // aren't set up yet this lookup simply finds nothing and lets it through.
    const { data: acct } = await admin
      .from('agents')
      .select('status_id, account_statuses(allows_access)')
      .eq('id', agentId)
      .maybeSingle();
    const allows = (acct as any)?.account_statuses?.allows_access;
    if (allows === false) return json({ error: 'Your account is not currently active' }, 403);

    // This agent's own Spark token, set via the admin's "Connect MLS" tab.
    const { data: creds, error: credsErr } = await admin
      .from('mls_credentials')
      .select('access_token, auth_type')
      .eq('agent_id', agentId)
      .maybeSingle();
    if (credsErr) return json({ error: 'Could not check your MLS connection' }, 500);
    if (!creds) return json({ error: 'Connect your MLS first (see the Connect MLS tab)' }, 400);

    let sparkToken: string | null = creds.access_token;
    if (creds.auth_type === 'oidc') {
      sparkToken = await getOidcAccessToken(admin, agentId);
      if (!sparkToken) {
        return json({ error: 'Your Flexmls connection has expired — please reconnect your MLS on the Connect MLS tab.' }, 400);
      }
    }

    const { mlsNumber } = await req.json();
    if (!mlsNumber || typeof mlsNumber !== 'string') return json({ error: 'mlsNumber is required' }, 400);
    const cleanMls = mlsNumber.trim().replace(/'/g, '');

    const sparkHeaders = { Authorization: `Bearer ${sparkToken}`, Accept: 'application/json' };

    // Try the number exactly as typed first, then — since MLS numbers with a
    // dash (e.g. "26-274631") are sometimes stored by Spark without it —
    // retry with non-alphanumerics stripped.
    async function trySparkFilter(idValue: string) {
      const filter = `ListingId Eq '${idValue}'`;
      const res = await fetch(
        `${API_BASE}/v1/listings?_filter=${encodeURIComponent(filter)}`,
        { headers: sparkHeaders }
      );
      const body = await res.json();
      return { res, body };
    }

    let attempt = await trySparkFilter(cleanMls);
    const strippedMls = cleanMls.replace(/[^a-zA-Z0-9]/g, '');
    if (attempt.body?.D?.Success && !attempt.body.D.Results?.length && strippedMls !== cleanMls) {
      attempt = await trySparkFilter(strippedMls);
    }
    const { res: listingRes, body: listingJson } = attempt;

    if (!listingRes.ok || !listingJson?.D?.Success) {
      return json({ error: listingJson?.D?.Message || 'Spark API request failed — check your MLS connection is still valid' }, 502);
    }
    const results: any[] = listingJson.D.Results || [];
    if (!results.length) {
      // Say how much of the MLS this connection can see at all, so "not found"
      // can be told apart from "this connection sees a tiny/test feed" or
      // "that listing isn't in the part of the feed this key can read".
      let seen = '';
      try {
        const countRes = await fetch(`${API_BASE}/v1/listings?_pagination=count`, { headers: sparkHeaders });
        const total = (await countRes.json())?.D?.Pagination?.TotalRows;
        if (typeof total === 'number') seen = ` This connection can see ${total.toLocaleString('en-US')} listing${total === 1 ? '' : 's'} in total.`;
        // A few examples (number, city, status) — shows which MLS/board this
        // connection is really reading and how its listing numbers look.
        const sampleRes = await fetch(
          `${API_BASE}/v1/listings?_limit=3&_select=ListingId,City,StateOrProvince,StandardStatus`,
          { headers: sparkHeaders }
        );
        const sample = ((await sampleRes.json())?.D?.Results || [])
          .map((r: any) => `${r?.StandardFields?.ListingId} (${[r?.StandardFields?.City, r?.StandardFields?.StateOrProvince].filter(Boolean).join(', ')}, ${r?.StandardFields?.StandardStatus})`)
          .join('; ');
        if (sample) seen += ` Examples it can see: ${sample}.`;
      } catch (_e) { /* just omit the extra detail */ }
      return json({ error: `No listing found for MLS #${cleanMls}.${seen}` }, 404);
    }
    // If more than one listing shares this number, prefer an Active one and
    // tell the agent so they can double-check it's the right property.
    const isActive = (r: any) => /^(active|coming)/i.test(r?.StandardFields?.StandardStatus || r?.StandardFields?.MlsStatus || '');
    const listing = results.find(isActive) || results[0];
    const f = listing.StandardFields || {};

    // Anything the agent should know about (things that didn't come through)
    // goes back as `notes` and is shown next to the Fetch button.
    const notes: string[] = [];
    if (results.length > 1) {
      notes.push(`${results.length} listings share this MLS number — pulled ${f.UnparsedFirstLineAddress || 'the first one'}. Check it's the right property.`);
    }

    // Photos: fetch the list, download each, re-upload into our own Storage
    // under this agent's own folder (matches the storage.objects RLS policy:
    // first path segment must equal the uploader's auth.uid()).
    let heroUrl: string | null = null;
    const galleryUrls: string[] = [];
    let photoCount = 0;
    let photoFailures = 0;
    let photoProblem = '';
    try {
      const photosRes = await fetch(
        `${API_BASE}/v1/listings/${listing.Id}/photos`,
        { headers: sparkHeaders }
      );
      const photosJson = await photosRes.json();
      if (!photosRes.ok || photosJson?.D?.Success === false) {
        photoProblem = photosJson?.D?.Message || `Spark returned HTTP ${photosRes.status}`;
      }
      const allPhotos = photosJson?.D?.Results || [];
      photoCount = allPhotos.length;
      const primary = allPhotos.find((p: any) => p.Primary);
      const rest = allPhotos.filter((p: any) => !p.Primary).slice(0, 10);
      const photos = primary ? [primary, ...rest] : allPhotos.slice(0, 11);
      for (const p of photos) {
        const srcUrl = p.Uri1600 || p.UriLarge || p.Uri1024 || p.Uri800;
        if (!srcUrl) { photoFailures++; continue; }
        try {
          const imgRes = await fetch(srcUrl);
          if (!imgRes.ok) { photoFailures++; if (!photoProblem) photoProblem = `photo download returned HTTP ${imgRes.status}`; continue; }
          const imgBuf = new Uint8Array(await imgRes.arrayBuffer());
          const path = `${agentId}/mls-import/${cleanMls}/${p.Id}.jpg`;
          const { error: upErr } = await admin.storage
            .from('property-photos')
            .upload(path, imgBuf, { contentType: 'image/jpeg', upsert: true });
          if (upErr) { photoFailures++; if (!photoProblem) photoProblem = `saving a photo failed: ${upErr.message}`; continue; }
          const { data: pub } = admin.storage.from('property-photos').getPublicUrl(path);
          if (p.Primary) heroUrl = pub.publicUrl;
          else galleryUrls.push(pub.publicUrl);
        } catch (e) { photoFailures++; if (!photoProblem) photoProblem = String((e as Error)?.message || e); }
      }
    } catch (e) { photoProblem = String((e as Error)?.message || e); }
    if (!heroUrl && galleryUrls.length) heroUrl = galleryUrls.shift()!;
    if (!heroUrl && !galleryUrls.length) {
      if (photoProblem) notes.push(`Photos could not be pulled (${photoProblem}).`);
      else if (photoCount === 0) notes.push('The MLS returned no photos for this listing — add them manually.');
    } else if (photoFailures) {
      notes.push(`${photoFailures} photo${photoFailures === 1 ? '' : 's'} could not be saved${photoProblem ? ` (${photoProblem})` : ''}.`);
    }

    // Virtual tour: the listing record's own tour fields first, then Spark's
    // virtual-tours list. Only a Matterport link fills the Matterport field.
    const tourUrls: string[] = [];
    for (const u of [f.VirtualTourURLUnbranded, f.VirtualTourURLBranded]) if (u) tourUrls.push(String(u));
    try {
      const toursRes = await fetch(
        `${API_BASE}/v1/listings/${listing.Id}/virtualtours`,
        { headers: sparkHeaders }
      );
      const toursJson = await toursRes.json();
      for (const t of toursJson?.D?.Results || []) if (t?.Uri) tourUrls.push(String(t.Uri));
    } catch (_e) { /* no tour list available - not fatal */ }
    const matterportUrl = tourUrls.find((u) => /matterport\.com/i.test(u)) || '';
    if (!matterportUrl && tourUrls.length) {
      notes.push(`The MLS lists a virtual tour (${tourUrls[0]}) but it isn't a Matterport link, so it wasn't filled in.`);
    }

    const rooms = Object.entries(f.RoomType || {})
      .filter(([, v]) => v === true)
      .map(([k]) => k);

    const facts: [string, string][] = [];
    if (f.MLSAreaMajor) facts.push(['MLS Area', f.MLSAreaMajor]);
    if (f.ParcelNumber) facts.push(['Parcel #', f.ParcelNumber]);
    if (f.ElementarySchool) facts.push(['Elementary School', f.ElementarySchool]);
    if (f.MiddleOrJuniorSchool) facts.push(['Middle School', f.MiddleOrJuniorSchool]);
    if (f.HighSchool) facts.push(['High School', f.HighSchool]);
    if (f.GarageSpaces) facts.push(['Garage Spaces', String(f.GarageSpaces)]);

    const remarks = (f.PublicRemarks || '').trim();
    const blurb = remarks.length > 160 ? remarks.slice(0, 157).replace(/\s+\S*$/, '') + '…' : remarks;

    const cityLine = [f.City, f.StateOrProvince].filter(Boolean).join(', ') + (f.PostalCode ? ' ' + f.PostalCode : '');

    return json({
      data: {
        addr: f.UnparsedFirstLineAddress || '',
        city: cityLine,
        price: money(f.ListPrice ?? f.CurrentPrice),
        status: mapStatus(f.StandardStatus, f.MlsStatus),
        type: mapType(f.PropertyType, f.PropertySubType),
        mls: f.ListingId || cleanMls,
        beds: f.BedsTotal != null ? String(f.BedsTotal) : '',
        baths: f.BathroomsTotalDecimal != null ? String(f.BathroomsTotalDecimal) : '',
        sqft: f.BuildingAreaTotal ? Math.round(f.BuildingAreaTotal).toLocaleString('en-US') : '',
        lot: f.LotSizeAcres ? `${f.LotSizeAcres} ac` : '',
        subdivision: f.SubdivisionName || '',
        year_built: f.YearBuilt ? String(f.YearBuilt) : '',
        listed: (f.OnMarketDate || f.ListingContractDate || '').slice(0, 10),
        blurb,
        public_remarks: f.PublicRemarks || '',
        facts,
        rooms,
        lat: f.Latitude ?? null,
        lng: f.Longitude ?? null,
        hero_photo_url: heroUrl,
        gallery_photo_urls: galleryUrls,
        matterport_url: matterportUrl,
        notes,
      },
    });
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 500);
  }
});
