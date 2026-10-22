-- PerchQR — multi-tenant Supabase schema
-- Run once in Supabase Studio: SQL Editor -> New query -> paste this whole file -> Run.
-- Safe to re-run: everything uses IF NOT EXISTS / DROP POLICY IF EXISTS guards.
--
-- This generalizes the single-tenant schema proven out on utahrealestate.us
-- (C:\Users\scott\Scotts QR\supabase\schema.sql) by adding an `agents` table
-- and an `agent_id` column to every tenant-owned table, then changing write
-- policies from "any authenticated user" to "only your own rows". Public read
-- policies are UNCHANGED (still `using (true)`) — there's nothing sensitive in
-- these tables, and the public site scopes to one agent via the query itself
-- (agent_id resolved from the URL slug in app code), not via RLS.
--
-- See PLANNING.md for the reasoning behind every decision baked in here.

-- ============================================================
-- 1. agents table — one row per tenant, id = auth.users.id
-- ============================================================
create table if not exists public.agents (
  id                uuid primary key references auth.users(id) on delete cascade,
  slug              text not null unique,       -- perchqr.com/<slug> — lowercase [a-z0-9-], 3-40 chars, reserved-word-checked in app code
  display_name      text not null,               -- "Scott Bird"
  brokerage_name    text,                        -- "Stratum Real Estate Group"
  phone             text,                        -- digits only, e.g. "4355907106" — perch.js formats for display
  email             text,
  headshot_url      text,
  logo_url          text,
  license_number    text,
  address_line      text,
  google_url        text,                        -- optional "connect with Google" link (Business Profile etc.)
  facebook_url      text,                        -- optional Facebook Page link
  subscription_status text not null default 'beta'
                      check (subscription_status in ('beta', 'trialing', 'active', 'past_due', 'canceled')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists agents_set_updated_at on public.agents;
create trigger agents_set_updated_at
  before update on public.agents
  for each row execute function public.set_updated_at();

-- Central owner check, used everywhere an agent-scoped policy needs a
-- PerchQR-the-company bypass (Scott can see/manage every agent's data —
-- support, moderation, helping someone mid-beta). Hardcoded to one id since
-- there's no real admin-roles table yet; swap the body for a role lookup if
-- PerchQR ever needs more than one privileged owner. `security definer` so
-- it can be called from any policy regardless of the caller's own grants.
create or replace function public.is_perchqr_owner()
returns boolean language sql stable security definer as $$
  select auth.uid() = '72158799-b0f4-47c9-ac2a-45ffe52db1df'::uuid;
$$;

alter table public.agents enable row level security;

-- Public read: agent profile fields are the same info a realtor already
-- publishes everywhere (name, phone, brokerage) — needed to render every
-- agent's public site header/contact section without that visitor being
-- signed in as anyone.
drop policy if exists "agents_public_read" on public.agents;
create policy "agents_public_read"
  on public.agents for select
  to anon, authenticated
  using (true);

-- Agents can edit their own row; Scott can edit any agent's row.
drop policy if exists "agents_self_write" on public.agents;
create policy "agents_self_write"
  on public.agents for update
  to authenticated
  using (id = auth.uid() or public.is_perchqr_owner())
  with check (id = auth.uid() or public.is_perchqr_owner());

-- Self-serve signup: a newly authenticated user may create their OWN agents
-- row (id must match their own auth id — they can't create one for anyone
-- else). Format/reserved-word enforcement lives in the CHECK constraints
-- below, not here, so it holds regardless of which client makes the request.
drop policy if exists "agents_self_insert" on public.agents;
create policy "agents_self_insert"
  on public.agents for insert
  to authenticated
  with check (id = auth.uid() or public.is_perchqr_owner());

-- Slug format: lowercase letters/digits, single hyphens between words, no
-- leading/trailing hyphen, 3-40 chars. Matches the app-level rule in
-- PLANNING.md's "Tenant URL shape" — enforced here too since a self-serve
-- signup form is no longer the only way a row could be written.
alter table public.agents drop constraint if exists agents_slug_format;
alter table public.agents add constraint agents_slug_format
  check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) between 3 and 40);

-- Reserved words a slug can never claim — see PLANNING.md's reserved-slugs
-- list. Grow this list in lockstep with any new top-level route.
alter table public.agents drop constraint if exists agents_slug_not_reserved;
alter table public.agents add constraint agents_slug_not_reserved
  check (slug not in (
    'app','admin','api','www','mail','cdn','static','assets',
    'login','signup','signin','signout','logout','account',
    'billing','dashboard','settings','pricing','about','blog',
    'help','support','docs','terms','privacy','status','q','s'
  ));

-- ============================================================
-- 2. mls_credentials — kept OUT of `agents` and locked down hard.
--    Each agent self-serves a free per-agent Spark access token (see
--    PLANNING.md "RESOLVED" entry) and pastes it into PerchQR's "Connect your
--    MLS" screen. No anon access at all, ever.
-- ============================================================
create table if not exists public.mls_credentials (
  agent_id          uuid primary key references public.agents(id) on delete cascade,
  mls_name          text not null,               -- "Washington County Board of REALTORS"
  flexmls_username  text,                        -- their own Flexmls login, for support/reference only
  access_token      text not null,               -- SENSITIVE — Spark API access token
  api_feed_id       text,                        -- non-sensitive per Spark's own docs, kept for support reference
  connected_at      timestamptz not null default now()
);
-- TODO before scaling past beta: move `access_token` to Supabase Vault
-- (pgsodium) for true at-rest encryption instead of a plain column protected
-- only by RLS. Fine for beta scale, not fine forever.

alter table public.mls_credentials enable row level security;

drop policy if exists "mls_credentials_owner_only" on public.mls_credentials;
create policy "mls_credentials_owner_only"
  on public.mls_credentials for all
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner())
  with check (agent_id = auth.uid() or public.is_perchqr_owner());
-- No policy at all for `anon` — completely inaccessible to the public site.
-- The MLS-lookup Edge Function reads any agent's token via the service_role
-- key (which bypasses RLS), after verifying the caller's own auth session.

-- ============================================================
-- 3. properties table
-- ============================================================
create table if not exists public.properties (
  id                  text primary key,          -- slug + random suffix, generated in admin (already globally-unique in practice)
  agent_id            uuid not null references public.agents(id) on delete cascade,
  addr                text not null,
  city                text not null,
  full_addr           text generated always as (addr || ', ' || city) stored,
  price               text,
  orig_price          text,
  status              text not null default 'Active'
                        check (status in ('Active', 'Pending', 'Sold')),
  type                text not null default 'residential'
                        check (type in ('residential', 'land', 'business')),
  mls                 text,
  elev                text,
  beds                text,
  baths               text,
  sqft                text,
  lot                 text,
  subdivision         text,
  year_built          text,
  listed              text,
  blurb               text not null,
  public_remarks      text not null,
  facts               jsonb not null default '[]'::jsonb,   -- array of [label, value] pairs, order preserved
  rooms               text[] not null default '{}',
  lat                 numeric,
  lng                 numeric,
  matterport_url      text,
  testimonial         text,
  testimonial_name    text,
  hero_photo_url      text,
  gallery_photo_urls  text[] not null default '{}',
  video_url           text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists properties_agent_id_idx on public.properties(agent_id);

drop trigger if exists properties_set_updated_at on public.properties;
create trigger properties_set_updated_at
  before update on public.properties
  for each row execute function public.set_updated_at();

alter table public.properties enable row level security;

drop policy if exists "properties_public_read" on public.properties;
create policy "properties_public_read"
  on public.properties for select
  to anon, authenticated
  using (true);

drop policy if exists "properties_agent_write" on public.properties;
create policy "properties_agent_write"
  on public.properties for all
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner())
  with check (agent_id = auth.uid() or public.is_perchqr_owner());

-- ============================================================
-- 4. qr_codes table — admin-only. QR images encode a stable redirector
--    (perchqr.com/q/<id>), never the agent's slug, so printed signs survive
--    slug changes. See PLANNING.md "Tenant URL shape".
-- ============================================================
create table if not exists public.qr_codes (
  id          uuid primary key default gen_random_uuid(),
  agent_id    uuid not null references public.agents(id) on delete cascade,
  label       text not null,
  url         text not null,             -- destination the redirector sends visitors to
  image_url   text,                      -- composited PNG (with optional logo) in Storage
  created_at  timestamptz not null default now()
);

create index if not exists qr_codes_agent_id_idx on public.qr_codes(agent_id);

alter table public.qr_codes enable row level security;

drop policy if exists "qr_codes_agent_only" on public.qr_codes;
create policy "qr_codes_agent_only"
  on public.qr_codes for all
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner())
  with check (agent_id = auth.uid() or public.is_perchqr_owner());
-- No anon policy: the redirector page resolves `/q/<id>` server-side
-- (service_role or a public RPC limited to id+url), never a raw table read.

drop policy if exists "qr_codes_public_resolve" on public.qr_codes;
create policy "qr_codes_public_resolve"
  on public.qr_codes for select
  to anon
  using (true);
-- Public SELECT is allowed so the `/q/<id>` redirector page can look up the
-- destination URL client-side (same trust level as today's locate.html
-- pattern) — labels aren't sensitive, and only `id`/`url` are actually read.

-- ============================================================
-- 5. Storage buckets — objects live under `{agent_id}/...` so ownership is
--    enforceable from the path alone, no join needed.
-- ============================================================
insert into storage.buckets (id, name, public)
values
  ('property-photos', 'property-photos', true),
  ('property-videos', 'property-videos', true),
  ('qr-codes', 'qr-codes', false)
on conflict (id) do nothing;

drop policy if exists "property_media_public_read" on storage.objects;
create policy "property_media_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id in ('property-photos', 'property-videos'));

drop policy if exists "property_media_agent_write" on storage.objects;
create policy "property_media_agent_write"
  on storage.objects for all
  to authenticated
  using (
    bucket_id in ('property-photos', 'property-videos')
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_perchqr_owner())
  )
  with check (
    bucket_id in ('property-photos', 'property-videos')
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_perchqr_owner())
  );

drop policy if exists "qr_codes_bucket_agent_only" on storage.objects;
create policy "qr_codes_bucket_agent_only"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'qr-codes'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_perchqr_owner())
  )
  with check (
    bucket_id = 'qr-codes'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_perchqr_owner())
  );
-- Admin upload code must prefix every Storage path with the TARGET agent's
-- id (not necessarily the caller's own, now that the owner can act on any
-- agent's behalf) — e.g. `${agentId}/${propId}/hero-....jpg`.

-- ============================================================
-- 6. testimonials — per-agent, rotates on their homepage
-- ============================================================
create table if not exists public.testimonials (
  id           uuid primary key default gen_random_uuid(),
  agent_id     uuid not null references public.agents(id) on delete cascade,
  client_name  text not null,
  quote        text not null,
  property_id  text references public.properties(id) on delete set null,
  quote_length int generated always as (char_length(quote)) stored,
  created_at   timestamptz not null default now()
);

create index if not exists testimonials_agent_id_idx on public.testimonials(agent_id);

alter table public.testimonials enable row level security;

drop policy if exists "testimonials_public_read" on public.testimonials;
create policy "testimonials_public_read"
  on public.testimonials for select
  to anon, authenticated
  using (true);

drop policy if exists "testimonials_agent_write" on public.testimonials;
create policy "testimonials_agent_write"
  on public.testimonials for all
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner())
  with check (agent_id = auth.uid() or public.is_perchqr_owner());

-- ============================================================
-- 7. agent_settings — one row per agent (replaces the single-tenant
--    `site_settings` singleton): homepage video + editable marketing copy.
-- ============================================================
create table if not exists public.agent_settings (
  agent_id          uuid primary key references public.agents(id) on delete cascade,
  home_video_url    text,
  about_eyebrow     text,
  about_heading     text,
  about_description text
);

alter table public.agent_settings enable row level security;

drop policy if exists "agent_settings_public_read" on public.agent_settings;
create policy "agent_settings_public_read"
  on public.agent_settings for select
  to anon, authenticated
  using (true);

drop policy if exists "agent_settings_agent_write" on public.agent_settings;
create policy "agent_settings_agent_write"
  on public.agent_settings for all
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner())
  with check (agent_id = auth.uid() or public.is_perchqr_owner());

-- ============================================================
-- 8. qr_scans — analytics only. No notification webhook in v1 (the
--    single-tenant reference site's Google Apps Script email trigger was
--    Scott-specific personal automation; per-agent notification setup is
--    real onboarding friction, deferred past the beta — see PLANNING.md).
-- ============================================================
create table if not exists public.qr_scans (
  id          uuid primary key default gen_random_uuid(),
  agent_id    uuid not null references public.agents(id) on delete cascade,  -- denormalized from qr_code_id to keep RLS a single-column check
  qr_code_id  uuid references public.qr_codes(id) on delete set null,
  scanned_at  timestamptz not null default now(),
  lat         numeric,
  lng         numeric
);

create index if not exists qr_scans_agent_id_idx on public.qr_scans(agent_id);

alter table public.qr_scans enable row level security;

-- Public INSERT stays open — scans are logged by anonymous site visitors.
-- Accepted low-risk simplification for the beta: a visitor's client supplies
-- agent_id/qr_code_id, so a malicious actor could spoof another agent's scan
-- count, but no private data is exposed or altered by doing so.
drop policy if exists "qr_scans_public_insert" on public.qr_scans;
create policy "qr_scans_public_insert"
  on public.qr_scans for insert
  to anon, authenticated
  with check (true);

drop policy if exists "qr_scans_agent_read" on public.qr_scans;
create policy "qr_scans_agent_read"
  on public.qr_scans for select
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner());

drop policy if exists "qr_scans_agent_delete" on public.qr_scans;
create policy "qr_scans_agent_delete"
  on public.qr_scans for delete
  to authenticated
  using (agent_id = auth.uid() or public.is_perchqr_owner());

-- ============================================================
-- 9. site_settings — PerchQR's own COMPANY-wide settings (not
--    per-agent, not per-tenant). Currently just the perchqr.com
--    landing page's intro video. Singleton row (id = 1).
--
--    Write access is hardcoded to Scott's own agent id — there's no
--    admin-roles system yet, and one is overkill for a single-owner
--    beta. Revisit with a real roles table if PerchQR ever needs more
--    than one privileged owner.
-- ============================================================
create table if not exists public.site_settings (
  id                 int primary key default 1,
  landing_video_url  text,
  constraint site_settings_singleton check (id = 1)
);
insert into public.site_settings (id) values (1) on conflict (id) do nothing;

alter table public.site_settings enable row level security;

drop policy if exists "site_settings_public_read" on public.site_settings;
create policy "site_settings_public_read"
  on public.site_settings for select
  to anon, authenticated
  using (true);

drop policy if exists "site_settings_owner_write" on public.site_settings;
create policy "site_settings_owner_write"
  on public.site_settings for update
  to authenticated
  using (public.is_perchqr_owner())
  with check (public.is_perchqr_owner());
