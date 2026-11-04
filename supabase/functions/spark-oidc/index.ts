// Connects an agent's Flexmls account to PerchQR using Spark's OpenID Connect
// flow ("Connect your Flexmls account" on the dashboard's Connect MLS tab),
// replacing the old copy-and-paste-an-access-token step.
//
//   action "start"      -> returns the Flexmls sign-in URL to send the agent to
//   action "callback"   -> called by /oauth/spark/callback with the `code` and
//                          `state` Flexmls sent back; exchanges the code for
//                          tokens (this needs the client secret, so it can only
//                          happen here, server-side) and stores them
//   action "disconnect" -> forgets the agent's tokens
//
// Secrets (Project Settings -> Edge Functions -> Secrets). NEVER put these in
// the repo or the browser:
//   SPARK_OIDC_CLIENT_ID      the key's "OAuth Key"
//   SPARK_OIDC_CLIENT_SECRET  the key's "OAuth Secret"
// Optional (defaults shown) — change only if FBS points us at other hosts:
//   SPARK_AUTH_BASE=https://sparkplatform.com
//   SPARK_API_BASE=https://replication.sparkapi.com
//   SPARK_OIDC_REDIRECT_URI=https://perchqr.com/oauth/spark/callback
//
// Like mls-lookup, this verifies the caller's own Supabase session, only ever
// touches that same agent's rows, and runs with the service role (the token
// table has no client-facing policies at all).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CLIENT_ID = Deno.env.get('SPARK_OIDC_CLIENT_ID') || '';
const CLIENT_SECRET = Deno.env.get('SPARK_OIDC_CLIENT_SECRET') || '';
const AUTH_BASE = (Deno.env.get('SPARK_AUTH_BASE') || 'https://sparkplatform.com').replace(/\/$/, '');
const API_BASE = (Deno.env.get('SPARK_API_BASE') || 'https://replication.sparkapi.com').replace(/\/$/, '');
const REDIRECT_URI = Deno.env.get('SPARK_OIDC_REDIRECT_URI') || 'https://perchqr.com/oauth/spark/callback';

const STATE_LIFETIME_MS = 10 * 60 * 1000;

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

// ---- signed `state` ------------------------------------------------------
// The state we hand to Flexmls (and get back unchanged) is signed with the
// client secret and carries the agent id + an expiry, so the callback can
// prove it's finishing the same agent's own sign-in, within 10 minutes.
const enc = new TextEncoder();

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64urlDecode(s: string): Uint8Array {
  const pad = '='.repeat((4 - (s.length % 4)) % 4);
  const bin = atob(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}
async function sign(data: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', enc.encode(CLIENT_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64url(new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(data))));
}
async function makeState(agentId: string): Promise<string> {
  const payload = b64url(enc.encode(JSON.stringify({ a: agentId, n: crypto.randomUUID(), e: Date.now() + STATE_LIFETIME_MS })));
  return `${payload}.${await sign(payload)}`;
}
async function stateIsValid(state: string, agentId: string): Promise<boolean> {
  const [payload, sig] = String(state || '').split('.');
  if (!payload || !sig) return false;
  const expected = await sign(payload);
  if (expected.length !== sig.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ sig.charCodeAt(i);
  if (diff !== 0) return false;
  try {
    const p = JSON.parse(new TextDecoder().decode(b64urlDecode(payload)));
    return p.a === agentId && typeof p.e === 'number' && p.e > Date.now();
  } catch (_e) {
    return false;
  }
}

// ---- Spark token endpoint ------------------------------------------------
async function postToken(params: Record<string, string>) {
  // Spark's docs show a JSON body; fall back to a form body if the endpoint
  // rejects the format (and only then, so a used code isn't retried blindly).
  let res = await fetch(`${AUTH_BASE}/openid/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(params),
  });
  if (res.status === 415 || res.status === 400) {
    const first = await res.clone().json().catch(() => ({}));
    if (first?.error !== 'invalid_grant') {
      res = await fetch(`${AUTH_BASE}/openid/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
        body: new URLSearchParams(params).toString(),
      });
    }
  }
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });

  try {
    if (!CLIENT_ID || !CLIENT_SECRET) {
      return json({ error: 'The Flexmls connection isn\'t set up on the server yet.' }, 500);
    }

    const jwt = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
    if (!jwt) return json({ error: 'Not authenticated' }, 401);
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: 'Not authenticated' }, 401);
    const agentId = userData.user.id;

    // Respect the account's status (see account_statuses.allows_access).
    const { data: acct } = await admin
      .from('agents')
      .select('mls_name, status_id, account_statuses(allows_access)')
      .eq('id', agentId)
      .maybeSingle();
    if ((acct as any)?.account_statuses?.allows_access === false) {
      return json({ error: 'Your account is not currently active' }, 403);
    }

    const { action, code, state } = await req.json();

    // ---- start: where to send the agent to sign in to Flexmls ----------
    if (action === 'start') {
      const params = new URLSearchParams({
        client_id: CLIENT_ID,
        scope: 'openid',
        response_type: 'code',
        redirect_uri: REDIRECT_URI,
        state: await makeState(agentId),
        nonce: crypto.randomUUID(),
      });
      return json({ url: `${AUTH_BASE}/openid/authorize?${params.toString()}` });
    }

    // ---- callback: finish the sign-in, store the tokens ----------------
    if (action === 'callback') {
      if (!code || typeof code !== 'string' || !state || typeof state !== 'string') {
        return json({ error: 'The Flexmls sign-in didn\'t come back complete — please try connecting again.' }, 400);
      }
      if (!(await stateIsValid(state, agentId))) {
        return json({ error: 'That Flexmls sign-in expired or doesn\'t match your account — please try connecting again.' }, 400);
      }

      const tok = await postToken({
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        grant_type: 'authorization_code',
        code,
        redirect_uri: REDIRECT_URI,
      });
      if (!tok.ok || !tok.body?.access_token) {
        const why = tok.body?.error_description || tok.body?.error || `HTTP ${tok.status}`;
        return json({ error: `Flexmls wouldn't complete the connection (${why}). Please try again.` }, 502);
      }
      const accessToken: string = tok.body.access_token;
      const refreshToken: string | null = tok.body.refresh_token || null;
      const expiresAt = new Date(Date.now() + (Number(tok.body.expires_in) || 86400) * 1000).toISOString();

      // Who just connected? Best effort — the connection works without it.
      let account: Record<string, unknown> | null = null;
      try {
        const meRes = await fetch(`${API_BASE}/v1/my/account`, {
          headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
        });
        const me = await meRes.json();
        const r = me?.D?.Results?.[0];
        if (r) {
          account = {};
          for (const k of ['Id', 'Name', 'Office', 'Mls', 'MlsId', 'UserType']) if (r[k] != null) account[k] = r[k];
        }
      } catch (_e) { /* not fatal */ }

      const { error: tokErr } = await admin.from('spark_oidc_tokens').upsert({
        agent_id: agentId,
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_at: expiresAt,
        spark_account: account,
        connected_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
      if (tokErr) return json({ error: 'Connected to Flexmls, but saving the connection failed — please try again.' }, 500);

      // The dashboard's "connected" row (tokens themselves stay in the table above).
      const { data: existing } = await admin.from('mls_credentials').select('mls_name').eq('agent_id', agentId).maybeSingle();
      const mlsName = existing?.mls_name || (acct as any)?.mls_name || 'Flexmls';
      const { error: credErr } = await admin.from('mls_credentials').upsert({
        agent_id: agentId,
        mls_name: mlsName,
        flexmls_username: (account?.Name as string) || null,
        access_token: 'oidc',
        auth_type: 'oidc',
        api_feed_id: null,
        connected_at: new Date().toISOString(),
      });
      if (credErr) return json({ error: 'Connected to Flexmls, but saving the connection failed — please try again.' }, 500);

      return json({ ok: true, name: (account?.Name as string) || null });
    }

    // ---- disconnect ----------------------------------------------------
    if (action === 'disconnect') {
      await admin.from('spark_oidc_tokens').delete().eq('agent_id', agentId);
      await admin.from('mls_credentials').delete().eq('agent_id', agentId).eq('auth_type', 'oidc');
      return json({ ok: true });
    }

    return json({ error: 'Unknown action' }, 400);
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 500);
  }
});
