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

-- Agent's chosen website color (one hex value, e.g. '#1F6FEB'); the public
-- pages derive their hover/tint shades from it. Null = the default theme.
-- Added after the table's first release, hence ALTER rather than only the
-- create-table above.
alter table public.agents add column if not exists brand_color text;
alter table public.agents drop constraint if exists agents_brand_color_format;
alter table public.agents add constraint agents_brand_color_format
  check (brand_color is null or brand_color ~ '^#[0-9a-fA-F]{6}$');

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

-- ============================================================
-- 10. Account management — subscription tiers, account statuses,
--     beta-tester flag, permanent audit history.
--
--     Framework only: NOTHING here decides pricing, features, or limits for
--     any tier. Tiers and statuses are rows (stable text ids, editable
--     display names), not hard-coded enums, so they can be renamed/extended
--     later without touching user accounts. Accounts are never deleted by
--     the admin tooling — "Archived" is a status, and every record stays.
--
--     Legacy note: agents.subscription_status (above) predates this and mixed
--     tier and status together. It is left untouched and unused.
-- ============================================================

-- 10a. Subscription tiers (configuration, separate from accounts).
create table if not exists public.subscription_tiers (
  id                  text primary key check (id ~ '^[a-z0-9_]+$'),  -- stable key; never shown, never changes
  name                text not null,                                   -- display name, editable
  description         text,
  price_monthly_cents integer check (price_monthly_cents is null or price_monthly_cents >= 0),
  price_annual_cents  integer check (price_annual_cents is null or price_annual_cents >= 0),
  features            jsonb not null default '{}'::jsonb,   -- future: which features this tier unlocks
  limits              jsonb not null default '{}'::jsonb,   -- future: listing caps, usage limits, trial rules...
  sort_order          integer not null default 100,
  is_active           boolean not null default true,        -- inactive = can't be newly assigned; never deleted
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

drop trigger if exists subscription_tiers_set_updated_at on public.subscription_tiers;
create trigger subscription_tiers_set_updated_at
  before update on public.subscription_tiers
  for each row execute function public.set_updated_at();

insert into public.subscription_tiers (id, name, sort_order) values
  ('beta',   'Beta',   10),
  ('free',   'Free',   20),
  ('tier_1', 'Tier 1', 30),
  ('tier_2', 'Tier 2', 40),
  ('tier_3', 'Tier 3', 50)
on conflict (id) do nothing;

alter table public.subscription_tiers enable row level security;

drop policy if exists "subscription_tiers_read" on public.subscription_tiers;
create policy "subscription_tiers_read"
  on public.subscription_tiers for select
  to authenticated
  using (true);

drop policy if exists "subscription_tiers_owner_insert" on public.subscription_tiers;
create policy "subscription_tiers_owner_insert"
  on public.subscription_tiers for insert
  to authenticated
  with check (public.is_perchqr_owner());

drop policy if exists "subscription_tiers_owner_update" on public.subscription_tiers;
create policy "subscription_tiers_owner_update"
  on public.subscription_tiers for update
  to authenticated
  using (public.is_perchqr_owner())
  with check (public.is_perchqr_owner());
-- No delete policy: tiers are deactivated, never deleted.

-- 10b. Account statuses. `allows_access` is the single switch that decides
--      whether an account may use its dashboard / write its data; change it
--      per status here when the operating rules for paused/canceled/pending
--      are defined. (Pending = awaiting activation, so no access yet; new
--      self-serve signups are created Active — see site_settings below.)
create table if not exists public.account_statuses (
  id            text primary key check (id ~ '^[a-z0-9_]+$'),
  name          text not null,
  description   text,
  allows_access boolean not null default false,
  sort_order    integer not null default 100
);

insert into public.account_statuses (id, name, description, allows_access, sort_order) values
  ('active',    'Active',    'Account is active and authorized to use its assigned features.', true,  10),
  ('pending',   'Pending',   'Account has been created but is awaiting activation or approval.', false, 20),
  ('paused',    'Paused',    'Account has been temporarily paused. Account information is retained.', false, 30),
  ('suspended', 'Suspended', 'Account has been restricted by an administrator.', false, 40),
  ('canceled',  'Canceled',  'Subscription or account service has been canceled, but all information remains accessible to administrators.', false, 50),
  ('archived',  'Archived',  'Removed from the normal active user list but permanently accessible to administrators.', false, 60)
on conflict (id) do nothing;

alter table public.account_statuses enable row level security;

drop policy if exists "account_statuses_read" on public.account_statuses;
create policy "account_statuses_read"
  on public.account_statuses for select
  to authenticated
  using (true);

drop policy if exists "account_statuses_owner_update" on public.account_statuses;
create policy "account_statuses_owner_update"
  on public.account_statuses for update
  to authenticated
  using (public.is_perchqr_owner())
  with check (public.is_perchqr_owner());

-- 10c. What a brand-new self-serve signup starts as (editable later without
--      code changes). Signup is the request (PLANNING.md 2026-10-22), so
--      new accounts start Active on the Beta tier and flagged as beta testers.
alter table public.site_settings add column if not exists default_signup_tier text not null default 'beta';
alter table public.site_settings add column if not exists default_signup_status text not null default 'active';
alter table public.site_settings add column if not exists default_signup_beta_tester boolean not null default true;

-- 10d. Account fields on agents. Existing accounts migrate as Beta / Active /
--      beta tester (the column defaults fill them in); nothing is overwritten.
alter table public.agents add column if not exists tier_id text not null default 'beta' references public.subscription_tiers(id);
alter table public.agents add column if not exists status_id text not null default 'active' references public.account_statuses(id);
alter table public.agents add column if not exists is_beta_tester boolean not null default true;
alter table public.agents add column if not exists status_changed_at timestamptz not null default now();
alter table public.agents add column if not exists admin_notes text;
alter table public.agents add column if not exists last_activity_at timestamptz;

create index if not exists agents_status_id_idx on public.agents(status_id);
create index if not exists agents_tier_id_idx on public.agents(tier_id);

-- Best starting value for "last activity" on existing accounts.
update public.agents a
   set last_activity_at = u.last_sign_in_at
  from auth.users u
 where u.id = a.id and a.last_activity_at is null and u.last_sign_in_at is not null;

-- 10e. Permanent audit history. Rows are only ever added by the admin RPC
--      below; there are no insert/update/delete policies for clients, and
--      API callers are blocked from changing or removing rows. `restrict`
--      (not cascade) so removing an account can never silently erase its
--      history.
create table if not exists public.account_history (
  id             uuid primary key default gen_random_uuid(),
  agent_id       uuid not null references public.agents(id) on delete restrict,
  kind           text not null check (kind in ('tier', 'status', 'beta_tester')),
  previous_value text,
  new_value      text,
  changed_by     uuid,                         -- the administrator's auth id (null = set by the migration)
  changed_at     timestamptz not null default now(),
  reason         text
);

create index if not exists account_history_agent_idx on public.account_history(agent_id, changed_at desc);

alter table public.account_history enable row level security;

drop policy if exists "account_history_owner_read" on public.account_history;
create policy "account_history_owner_read"
  on public.account_history for select
  to authenticated
  using (public.is_perchqr_owner());

revoke insert, update, delete on public.account_history from anon, authenticated;

create or replace function public.account_history_immutable()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null then
    raise exception 'Account history cannot be edited or erased' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists account_history_no_edit on public.account_history;
create trigger account_history_no_edit
  before update or delete on public.account_history
  for each row execute function public.account_history_immutable();

-- Starting entry for accounts that existed before this system.
insert into public.account_history (agent_id, kind, previous_value, new_value, reason)
select a.id, 'tier', null, a.tier_id, 'Initial value when account management was introduced'
  from public.agents a
 where not exists (select 1 from public.account_history h where h.agent_id = a.id and h.kind = 'tier');
insert into public.account_history (agent_id, kind, previous_value, new_value, reason)
select a.id, 'status', null, a.status_id, 'Initial value when account management was introduced'
  from public.agents a
 where not exists (select 1 from public.account_history h where h.agent_id = a.id and h.kind = 'status');

-- 10f. Tier / status / beta-tester / notes belong to administrators only.
--      Agents can still edit their own profile row, but not these columns,
--      and a self-inserted row always gets the signup defaults. (Direct SQL
--      and the service role, which have no auth.uid(), are not restricted.)
create or replace function public.agents_guard_admin_fields()
returns trigger language plpgsql security definer set search_path = public as $$
declare d record;
begin
  if auth.uid() is null or public.is_perchqr_owner() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    select default_signup_tier, default_signup_status, default_signup_beta_tester
      into d from public.site_settings where id = 1;
    new.tier_id          := coalesce(d.default_signup_tier, 'beta');
    new.status_id        := coalesce(d.default_signup_status, 'active');
    new.is_beta_tester   := coalesce(d.default_signup_beta_tester, true);
    new.admin_notes      := null;
    new.status_changed_at := now();
  else
    if new.tier_id is distinct from old.tier_id
       or new.status_id is distinct from old.status_id
       or new.is_beta_tester is distinct from old.is_beta_tester
       or new.admin_notes is distinct from old.admin_notes
       or new.status_changed_at is distinct from old.status_changed_at then
      raise exception 'Subscription tier, account status and notes can only be changed by an administrator'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists agents_guard_admin_fields_trg on public.agents;
create trigger agents_guard_admin_fields_trg
  before insert or update on public.agents
  for each row execute function public.agents_guard_admin_fields();

-- 10g. The one way an administrator changes a tier / status / beta-tester
--      flag: the update and its audit row happen in a single transaction, so
--      they can never disagree. Returns the updated agents row.
create or replace function public.admin_set_account_field(
  p_agent_id uuid, p_kind text, p_value text, p_reason text default null
) returns public.agents
language plpgsql security definer set search_path = public as $$
declare
  a public.agents;
  cur text;
begin
  if not public.is_perchqr_owner() then
    raise exception 'Only an administrator can change account settings' using errcode = '42501';
  end if;

  select * into a from public.agents where id = p_agent_id for update;
  if not found then raise exception 'Account not found'; end if;

  if p_kind = 'tier' then
    if not exists (select 1 from public.subscription_tiers where id = p_value) then
      raise exception 'Unknown subscription tier';
    end if;
    cur := a.tier_id;
    if cur = p_value then return a; end if;
    update public.agents set tier_id = p_value where id = p_agent_id returning * into a;

  elsif p_kind = 'status' then
    if not exists (select 1 from public.account_statuses where id = p_value) then
      raise exception 'Unknown account status';
    end if;
    if p_agent_id = auth.uid()
       and not (select allows_access from public.account_statuses where id = p_value) then
      raise exception 'You cannot restrict your own administrator account';
    end if;
    cur := a.status_id;
    if cur = p_value then return a; end if;
    update public.agents set status_id = p_value, status_changed_at = now()
     where id = p_agent_id returning * into a;

  elsif p_kind = 'beta_tester' then
    if p_value not in ('true', 'false') then raise exception 'Invalid value'; end if;
    cur := a.is_beta_tester::text;
    if cur = p_value then return a; end if;
    update public.agents set is_beta_tester = (p_value = 'true')
     where id = p_agent_id returning * into a;

  else
    raise exception 'Unknown account field';
  end if;

  insert into public.account_history (agent_id, kind, previous_value, new_value, changed_by, reason)
  values (p_agent_id, p_kind, cur, p_value, auth.uid(), nullif(trim(coalesce(p_reason, '')), ''));

  return a;
end;
$$;

revoke all on function public.admin_set_account_field(uuid, text, text, text) from public, anon;
grant execute on function public.admin_set_account_field(uuid, text, text, text) to authenticated;

-- 10h. "Last activity": the dashboard calls this when an agent signs in /
--      opens it (at most once every 10 minutes per agent).
create or replace function public.touch_my_activity()
returns void language sql security definer set search_path = public as $$
  update public.agents
     set last_activity_at = now()
   where id = auth.uid()
     and (last_activity_at is null or last_activity_at < now() - interval '10 minutes');
$$;

revoke all on function public.touch_my_activity() from public, anon;
grant execute on function public.touch_my_activity() to authenticated;

-- 10i. Access enforcement in the database. An account whose status does not
--      allow access (pending, paused, suspended, canceled, archived) can no
--      longer write through the API, even with a still-valid session. All
--      data stays in place. Administrators (is_perchqr_owner) are unaffected.
--      The policies below REPLACE the same-named ones defined earlier in this
--      file, so re-running the whole file keeps them in force.
create or replace function public.account_allows_access(p_agent_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.allows_access
       from public.agents a
       join public.account_statuses s on s.id = a.status_id
      where a.id = p_agent_id),
    true);
$$;

create or replace function public.is_agent_self(p_agent_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_agent_id = auth.uid() and public.account_allows_access(p_agent_id);
$$;

drop policy if exists "agents_self_write" on public.agents;
create policy "agents_self_write"
  on public.agents for update
  to authenticated
  using (public.is_agent_self(id) or public.is_perchqr_owner())
  with check (public.is_agent_self(id) or public.is_perchqr_owner());

drop policy if exists "mls_credentials_owner_only" on public.mls_credentials;
create policy "mls_credentials_owner_only"
  on public.mls_credentials for all
  to authenticated
  using (public.is_agent_self(agent_id) or public.is_perchqr_owner())
  with check (public.is_agent_self(agent_id) or public.is_perchqr_owner());

drop policy if exists "properties_agent_write" on public.properties;
create policy "properties_agent_write"
  on public.properties for all
  to authenticated
  using (public.is_agent_self(agent_id) or public.is_perchqr_owner())
  with check (public.is_agent_self(agent_id) or public.is_perchqr_owner());

drop policy if exists "qr_codes_agent_only" on public.qr_codes;
create policy "qr_codes_agent_only"
  on public.qr_codes for all
  to authenticated
  using (public.is_agent_self(agent_id) or public.is_perchqr_owner())
  with check (public.is_agent_self(agent_id) or public.is_perchqr_owner());

drop policy if exists "testimonials_agent_write" on public.testimonials;
create policy "testimonials_agent_write"
  on public.testimonials for all
  to authenticated
  using (public.is_agent_self(agent_id) or public.is_perchqr_owner())
  with check (public.is_agent_self(agent_id) or public.is_perchqr_owner());

drop policy if exists "agent_settings_agent_write" on public.agent_settings;
create policy "agent_settings_agent_write"
  on public.agent_settings for all
  to authenticated
  using (public.is_agent_self(agent_id) or public.is_perchqr_owner())
  with check (public.is_agent_self(agent_id) or public.is_perchqr_owner());

drop policy if exists "property_media_agent_write" on storage.objects;
create policy "property_media_agent_write"
  on storage.objects for all
  to authenticated
  using (
    bucket_id in ('property-photos', 'property-videos')
    and (((storage.foldername(name))[1] = auth.uid()::text and public.account_allows_access(auth.uid()))
         or public.is_perchqr_owner())
  )
  with check (
    bucket_id in ('property-photos', 'property-videos')
    and (((storage.foldername(name))[1] = auth.uid()::text and public.account_allows_access(auth.uid()))
         or public.is_perchqr_owner())
  );

drop policy if exists "qr_codes_bucket_agent_only" on storage.objects;
create policy "qr_codes_bucket_agent_only"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'qr-codes'
    and (((storage.foldername(name))[1] = auth.uid()::text and public.account_allows_access(auth.uid()))
         or public.is_perchqr_owner())
  )
  with check (
    bucket_id = 'qr-codes'
    and (((storage.foldername(name))[1] = auth.uid()::text and public.account_allows_access(auth.uid()))
         or public.is_perchqr_owner())
  );

-- ============================================================
-- 11. MLS the agent named at signup (optional, free text from a short
--     dropdown + "Other"). Informational: demand tracking, support, and
--     pre-filling the Connect MLS tab. Agents can edit their own row, so
--     no extra policy is needed.
-- ============================================================
alter table public.agents add column if not exists mls_name text;

-- ============================================================
-- 12. Flexmls (Spark OIDC) connection. Agents click "Connect your Flexmls
--     account" instead of pasting a token. The OAuth tokens live in their
--     own table with NO client policies at all — only the server-side Edge
--     Functions (service role) can read or write them, so no browser, and
--     no script running in one, can ever see an agent's tokens. The agent's
--     mls_credentials row still exists (auth_type = 'oidc', placeholder in
--     access_token) so the dashboard can show "connected".
-- ============================================================
alter table public.mls_credentials add column if not exists auth_type text not null default 'token';
alter table public.mls_credentials drop constraint if exists mls_credentials_auth_type_check;
alter table public.mls_credentials add constraint mls_credentials_auth_type_check
  check (auth_type in ('token', 'oidc'));

create table if not exists public.spark_oidc_tokens (
  agent_id      uuid primary key references public.agents(id) on delete cascade,
  access_token  text not null,
  refresh_token text,
  expires_at    timestamptz,
  spark_account jsonb,                    -- non-sensitive bits of Spark's my/account (name, ids)
  connected_at  timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.spark_oidc_tokens enable row level security;
-- (deliberately no policies)
revoke all on public.spark_oidc_tokens from anon, authenticated;
-- TODO before scaling past beta: encrypt these at rest (Supabase Vault).

-- ============================================================
-- 13. Location verification (admin to-do). Coordinates that auto-fill from
--     the MLS / address lookup aren't always exact, so each property is
--     checked by the administrator (in Google Maps / Earth) and marked
--     verified. New properties start unverified; if an agent later changes a
--     property's coordinates or address it goes back to unverified. Only an
--     administrator can set the verified fields — agents can't.
-- ============================================================
alter table public.properties add column if not exists location_verified_at timestamptz;
alter table public.properties add column if not exists location_verified_by uuid;

create or replace function public.properties_guard_location_verified()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.is_perchqr_owner() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.location_verified_at := null;
    new.location_verified_by := null;
  elsif new.lat is distinct from old.lat or new.lng is distinct from old.lng
     or new.addr is distinct from old.addr or new.city is distinct from old.city then
    new.location_verified_at := null;
    new.location_verified_by := null;
  else
    new.location_verified_at := old.location_verified_at;
    new.location_verified_by := old.location_verified_by;
  end if;
  return new;
end;
$$;

drop trigger if exists properties_guard_location_verified_trg on public.properties;
create trigger properties_guard_location_verified_trg
  before insert or update on public.properties
  for each row execute function public.properties_guard_location_verified();

-- ============================================================
-- 14. Business card page text (Scott's /scott-bird/card page)
--     Written in the dashboard's owner-only "Business Card" tab and read by
--     site/card.html. Plain text: card_about uses blank lines between
--     paragraphs, card_highlights is one bullet per line. Covered by the
--     existing agent_settings policies (public read, owner/agent write).
-- ============================================================
alter table public.agent_settings add column if not exists card_about text;
alter table public.agent_settings add column if not exists card_highlights text;
