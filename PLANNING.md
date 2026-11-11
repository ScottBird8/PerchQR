# PerchQR — Planning & Open Questions

Working doc for the multi-tenant SaaS build. Update the Decision Log as things
get settled; keep the Open Questions list current so nothing gets lost between
sessions.

---

## Project context (2026-09-09)

**This is an unvalidated beta, not a launch.** Goal: build `perchqr.com`, give it
to 8–10 other agents, collect feedback, and decide from that whether PerchQR is
worth expanding and marketing. Scope every decision to *cheapest path to
validated learning* — don't build launch-grade infra (self-serve billing, MLS
expansion, polished onboarding) until the beta says the product is real.

- Product = **replicate utahrealestate.us**, multi-tenant. Agent's own branded
  page(s), QR codes, admin CRUD, MLS# → autofill. **No** IDX listing search.
- Beta rides Scott's own MLS (Iron County / Southern Utah). Other markets later.

---

## Decision Log

- **2026-09-09 — Name + domain: PerchQR / `perchqr.com`.** Bought on GoDaddy.
  Casing is always **PerchQR**. Rationale: exact-match `.com`, brandable, strong
  mascot potential (bird on a sign rider), room to grow past QR, warm tone for a
  relationship-driven buyer. Founder nod: Scott **Bird** → Perch.
  - Known trade-offs accepted: "Perch" + "QR" don't reinforce each other (name
    needs explaining); speaks more to buyer than agent; "QR" may age; no SEO pull
    on the root word; permanent brand/domain drift if product broadens past QR.
  - Prior use in-market to clear: **Perchwell** (active real-estate-pro software),
    Perch→Orchard, Perch Canada. TODO before printing signs / filing LLC:
    USPTO TESS search (classes 9/35/36/42) + Utah business-name registry.
  - TODO: grab `@perchqr` social handles (reminder scheduled 2026-09-10).

- **2026-09-09 — Billing: none for the beta.** Beta is free (or a flat "founding
  member" rate via a Stripe **Payment Link** — no code). Willingness-to-pay is
  gathered by asking beta agents directly. Build real billing only at a
  launch decision:
  - Stripe **Checkout** (hosted) + **Customer Portal** (hosted) — no card UI to build.
  - Webhook → Supabase Edge Function flips `agents.subscription_status` / `plan`
    on `checkout.session.completed`, `customer.subscription.updated|deleted`.
  - Gate public page + admin on `subscription_status`. One product / one price to
    start; annual, tiers, brokerage seats come later.
  - Scott already has a Stripe account.

- **2026-09-09 — Beta MLS access: notify FBS, likely ride Scott's existing access.**
  Plan: Scott is a member of the MLS and pays the fee; the beta adds a site that
  shows a few *other* same-MLS agents' own listings.
  - Risk to manage: the existing token also powers utahrealestate.us in
    production — if the MLS suspends it, that site goes down too. Mitigation:
    register a **separate free PerchQR Spark developer account** now so app
    credentials are isolated (MLS data access may still be shared or need its
    own $50/mo — MLS's call).
  - Sold-listing retention: **dropped** for the beta (manual entry only if ever
    needed).
  - Loss-making MLS setup for future markets: **deferred** — revisit at expansion.

- **2026-09-11 — Concrete Spark setup steps** [step 2's "generic agent" framing
  SUPERSEDED — see the RESOLVED entry further down: access is per-agent, not
  generic/shared] (from
  [sparkplatform.com/docs/overview/set_up_access](https://sparkplatform.com/docs/overview/set_up_access)):
  1. Register a **PerchQR** developer account (free) at
     `sparkplatform.com/register/developers` — ~3 business days, gives sandbox
     credentials to start building against.
  2. Request **"generic agent" status** on the key (not a bearer token tied to
     Scott's personal flexmls login) — this is the actual mechanism for one app
     serving multiple agents. OpenID Connect (each agent logs in with their own
     flexmls credentials) is the alternative if per-agent consent is wanted
     instead.
  3. Log into the **Datamart** (`sparkplatform.com/ticket`) with the new
     developer credentials, search for Scott's MLS/board, review data plans.
  4. Enroll in a plan: accept terms, and use the required "describe what you're
     creating / how data is used / who has access" field to **disclose the
     multi-agent beta and request generic-agent status** — this is the
     disclosure step, no separate email needed. MLS administration approves;
     credentials emailed.
  5. If the MLS isn't listed in the Datamart, contact them directly with the
     same info (project description, who gets access, role, generic-agent ask).
  6. **Role:** ask the MLS specifically — public per-agent listing pages likely
     need **IDX** role (Private is internal/agent-only), but this is narrower
     than board-wide IDX search, so ask if anything lighter applies.
  - TODO: identify Scott's exact MLS/board name for step 3.

- **2026-09-11 — Drafted "API Interest" description for Spark developer registration**
  (`sparkplatform.com/register/developers`). Form fields: Company Name → `PerchQR`;
  Website URL → `perchqr.com`; MLS/Data Source → Washington County; Flexmls
  Account → Scott's own WC username; API Interest (the real description field) →
  *"I'm building PerchQR (perchqr.com), a web application for real estate agents
  that gives each agent their own branded listing website with QR-code sign
  generation. An agent enters an MLS number and the app looks up that specific
  listing via the Spark API to auto-populate their property page — this is
  retrieval of individual listings by MLS #, not an MLS-wide search or IDX
  display of other agents' listings. I'm purchasing MLS data from the Spark
  Datamart for Washington County. I'm currently running a small beta with
  roughly 8–10 Washington County agents (in addition to myself) to gather
  feedback before deciding whether to expand further, so I'd like to request
  generic-agent access rather than a key tied only to my personal Flexmls login,
  so each participating agent's own listings can be retrieved through the app."*

- **2026-09-11 — Washington County BOR Datamart: plan options reviewed.**
  Six roles available: Own Data, Broker Back Office 3rd Party, Broker Back
  Office/Private, IDX, IDX for Large Syndication Vendors, VOW. VOW/Private/plain
  IDX ruled out (wrong shape). Leading candidate: **"A Broker or Agent's Own
  Data"** — free (no MLS charge; FBS's own per-MLS API fee may still apply).
  Description: *"restricts API access to listings or data from a specified
  broker or agent (their own listings, contacts, searches, etc.) and not
  listings from any other brokers or agents."* Two things this does NOT resolve,
  to raise at the "Purchase with Approval" step (reviewed by WCBOR admin):
  1. Does "a specified broker or agent" mean one grant = one named agent (so the
     beta needs one grant per participating agent), or can one grant cover
     several named agents?
  2. Does this role permit public display of the data (PerchQR's property pages
     are public/unauthenticated), or is it for private/internal use only?
  If public display isn't allowed under this role, fall back to reassessing
  "Broker Back Office 3rd Party" or "IDX for Large Syndication Vendors."
  One-grant-per-agent is an acceptable outcome for a free, beta-scale product —
  not a blocker, just more admin clicks.

- **2026-09-11 — RESOLVED: MLS credential model is per-agent, not shared.**
  Scott completed "Purchase with Approval" for real: **instant, free, auto-approved,
  zero human review** — no description field was ever presented, so the
  multi-agent disclosure never happened and evidently isn't required for this
  role. The approval confirmation reads *"This subscription request is on behalf
  of Flexmls user Scott L Bird (stg.sbird)"* — **confirming each grant is scoped
  to one named Flexmls user.** This settles open question #1 from the entry
  above: one grant = one agent, full stop. No "generic agent" option surfaced in
  this self-serve flow.
  - **This reverses the shared-per-MLS-credential architecture from 2026-09-09**
    ("MLS access model" entry below, and the "generic agent status" step in
    "Concrete Spark setup steps" above) — both superseded. The original
    README plan was right: **each agent gets and connects their own Spark
    access token.**
  - New model: PerchQR onboarding needs a **"Connect your MLS" step** — agent
    self-serves the free "Own Data" plan on their MLS's Spark Datamart (their
    own Flexmls login, ~5 min, instant approval) and pastes the resulting
    Access Token into PerchQR. Store it **encrypted, per-agent** (Supabase Vault
    / encrypted column) — never in a git-tracked file, never client-side. For
    the beta this can be a manual paste-in field; no OAuth flow needed yet.
  - Upside: no vendor registration/approval wait, $0 (at least from the board;
    watch for any FBS-side charge), and blast radius is naturally per-agent
    (one revoked token doesn't affect others) — resolves that earlier risk too.
  - Still open: whether this role permits public display (untested — no terms
    were shown during the instant approval). Low risk for a small beta; revisit
    if WCBOR ever raises it.
  - **Security note:** a real access token + API Feed ID were pasted into chat
    during this process. Not recorded in this file. Treat as a live secret —
    never commit it, store only in Supabase secrets/encrypted storage.

- **2026-09-11 — REOPENED: Scott wants one shared credential, not per-agent tokens.**
  Technical reality: the "Own Data" role (used above) is free/instant precisely
  *because* it's structurally capped to one named agent's own data ("not listings
  from any other brokers or agents") — no admin review needed since blast radius
  is inherently limited. A single credential covering multiple different agents'
  listings needs a genuinely different role. Two real candidates from the six:
  - **"Broker Back Office 3rd Party"** — description explicitly says "for 3rd
    party users needing private data access and not associated with one specific
    agent or brokerage." Best match on paper. Unknowns to check via More Info /
    Plans & Pricing: cost, whether it's instant or admin-reviewed, and whether it
    permits public display (name suggests private/internal use, which would be a
    problem for PerchQR's public property pages).
  - **"IDX" / "IDX for Large Syndication Vendors"** — board-wide data under one
    participant license, so it would also solve "any agent's MLS# works," but
    reintroduces the IDX compliance weight (display rules, possible broker
    sign-off) that the scope-narrowing decision specifically cut. Fallback, not
    first choice.
  - Per-agent "Own Data" tokens (resolved above) remain the fallback if the
    shared-credential roles turn out to require real review/cost/private-use
    restrictions that don't fit a lean beta.
  - **Confirmed reversible:** Datamart plans are independent subscriptions —
    holding "Own Data" now doesn't block requesting a shared-credential role
    later. Switching cost is dev-side only (where PerchQR reads the credential
    from), not a board lock-in.
  - **DECISION: proceed with per-agent tokens for the beta now** (already free
    and working) rather than blocking on investigating the shared-credential
    roles. Revisit shared-credential post-beta if onboarding friction is
    actually a problem, or once the product is validated enough to justify the
    likely extra review/cost.

- **2026-09-11 — Tenant isolation: single Supabase project + RLS on `agent_id`.**
  Project-per-tenant rejected as ops overkill at beta scale (8–10 separate
  schemas to keep in lockstep for zero benefit). Extends the existing reference
  `schema.sql` with a small, well-understood change:
  - New `agents` table: `id` = `auth.users.id`, `slug`, display/branding fields,
    `mls_member_id`, encrypted MLS token ref, (later) `subscription_status`.
  - Every tenant table (`properties`, `qr_codes`, `testimonials`, `qr_scans`;
    `site_settings`/`app_config` become per-agent rows, not a singleton) gets
    `agent_id uuid not null references agents(id)`.
  - Public read policies **unchanged** (`to anon, authenticated using (true)`)
    — the public site scopes by `agent_id` in the query (from the URL slug),
    not via RLS; nothing sensitive in these tables.
  - Write policies change from "any authenticated user" to **"only your own
    rows"**: `using (agent_id = auth.uid()) with check (agent_id = auth.uid())`.
    That's the entire multi-tenant leap.
  - Storage buckets: path convention `{agent_id}/...` + a policy matching the
    first path segment to `auth.uid()`. Public read stays open.

- **2026-09-11 — Hosting: Netlify, one static site, one deploy, GitHub CI.**
  Keep the existing stack — plain static HTML/CSS/JS + Supabase, no framework,
  no build step. Both reference sites already prove this works.
  - Tenant routing extends the existing `_redirects` pattern: explicit routes
    for `/app`, `/q/*`, and other reserved paths, THEN a catch-all rewrite
    `/:slug  /index.html  200` below them (Netlify matches top-to-bottom).
    `index.html`'s JS reads the first path segment instead of a query string.
  - **Action: connect the repo to Netlify's GitHub integration now** — `git
    push` → auto-deploy, no more manual drag-and-drop. Zero cost, do it day one.
  - Admin (`/app`) lives in the same static site/deploy, same as `admin.html`
    sits next to `index.html` today.
  - Supabase Edge Functions (MLS lookup) deploy separately via Supabase CLI,
    same as both reference repos already do.
  - **Scope cut:** for a hand-picked 8–10 agent beta, skip building the
    self-serve signup/MLS-picker flow designed earlier — Scott adds each beta
    agent's row to `agents` directly. Build self-serve signup only if/when this
    moves past beta.

- **2026-09-11 — Beta pilot MLS: Washington County (not Iron County).**
  Different board than the one powering utahrealestate.us / brianheadrealestate.com
  (Iron County) — this is a fresh Datamart enrollment, not "ride existing access"
  as earlier assumed. **Scott is already a Washington County MLS member**, so the
  generic-agent enrollment (Spark setup steps above, step 4) can proceed now —
  nothing blocking on establishing membership first.

- **2026-09-09 — Scope narrowed: replicate utahrealestate.us ONLY.**
  MLS# → autofill the agent's own listing. **No IDX "search all listings"
  feature** (the brianheadrealestate.com pattern is out of scope). This removes
  the heavy compliance path (display-all rules, broker sign-off).

- **2026-09-09 — MLS access model: MLS-optional signup + demand-driven expansion.**
  [Credential-model details (shared per-MLS token, generic-agent) SUPERSEDED
  2026-09-11 — see RESOLVED entry above: it's per-agent tokens. The $50/mo and
  demand-driven-expansion reasoning below may still apply to *other* future
  MLSs that don't offer a free self-serve own-data plan like WCBOR's.]
  - **No per-user / per-seat Spark fee.** Confirmed via Spark FAQ: "$50/mo for
    each MLS you can access; multiple API keys for one MLS = one $50/mo charge."
    Vendors serve many agents on one feed (cf. TourTime, MLSImport). PerchQR's
    cost is $50/mo per active MLS — pricing just needs margin over that.
  - **Still true, but they're permission steps, not fees:**
    - Per-MLS developer approval required ("Do I have to get permission from each
      MLS? Yes") — weeks, possible fees/review. This (+ the $50/mo) is why
      expansion is demand-driven, not per-user cost.
    - Each agent does a **one-time free authorize** — OAuth "connect your MLS
      account" (flexmls login) or an MLS-admin toggle. Needs a clean "Connect
      your MLS" onboarding screen.
    - IDX display rules on the public pages: disclaimer, attribution, refresh
      cadence, off-market takedown. Current site already does most of this.
    - Sold data: IDX feeds usually exclude sold; current site keeps sold
      listings w/ testimonials. Agent's own past sales likely OK — confirm, else
      manual-entry fallback for sold.
  - Scott's personal Iron County token can't power the commercial product —
    PerchQR needs its own vendor/developer registration with FBS/Spark.
  - **Signup is never blocked on MLS.** Manual entry + PDF import (already built)
    = day-1 path; MLS lookup is an autofill upgrade shown as a dashboard
    checklist: Not connected → Requested → Connect your MLS → Connected.
  - Credential model: one server-side token per MLS in `mls_boards`
    (id, name, aliases, provider, credential_ref, vendor_status); agent carries
    mls_board_id / mls_member_id / mls_auth_status. Lookups filter to the agent's
    own listings (`ListAgentMlsId`). Internal RLS still scopes by agent_id.
  - Signup UX: state/ZIP first → typeahead MLS picker (alias-aware) → supported =
    connect MLS account, unsupported = waitlist w/ honest timeline. No wall of
    grayed-out MLSs.
  - **Verify with FBS:** does "agent's own listings on their own branded page,
    pulled by MLS#" need full IDX role or something lighter (member's own data)?
    How do members authorize the app — OAuth or MLS-admin toggle?

- **2026-09-09 — Tenant URL shape: path-based, `perchqr.com/<agent-slug>`.**
  Subdomains rejected (ops cost — wildcard DNS/cert, cross-origin auth — with no
  real payoff when the URL is scanned from a QR, not typed). Custom domains
  (`agentbrand.com`) deferred to a paid add-on.
  - **QR codes encode a stable redirector ID, never the slug**:
    `perchqr.com/q/<uuid>` → server resolves to current slug/listing. Printed
    signs are permanent; this decouples them from slug changes. (Reference sites
    already do this via `locate.html?qr=<id>`.)
  - Slug rules: lowercase `[a-z0-9-]`, 3–40 chars, no leading/trailing/double
    hyphens. Changeable later; old slug 301s to new; keep slug history.
  - Reserved slugs (block at claim time, grow the list): `app admin api www mail
    cdn static assets login signup signin signout logout account billing
    dashboard settings pricing about blog help support docs terms privacy status
    q s`.
  - Authed dashboard at `perchqr.com/app` for v1 (single origin). `app.` subdomain
    is a fine later move (Supabase session is per-origin localStorage).
  - Custom domains later: `custom_domain` column, Host-header match, certs via
    host's SaaS-domain feature.

- **2026-09-12 — Chose "Fieldstone" as PerchQR's brand identity, added a QR
  logo, and rewrote landing copy around real value props.** Explored 3
  directions in an artifact (PerchQR Identity Studies) — slate/cedar palette,
  Fraunces/Karla/JetBrains Mono type, square mono step numbers, hairline-
  divided benefits grid. Kept the QR-corner-mark logo from a different
  direction ("Signal") instead of Fieldstone's original bird mark. Landing
  copy now leads with the video-introduction feature (the real, built
  differentiator) instead of a generic "your own site" pitch, and reframes
  the QR-durability point honestly: it doesn't reduce how many signs an agent
  buys, it means a printed sign never needs reprinting since the code points
  at a live page, not a fixed link. Dropped the unproven "converts more
  leads" claim — the beta is what tests that.

- **2026-09-12 — perchqr.com landing page can now show an intro video.**
  New `site_settings` singleton table (company-wide, not per-agent/tenant) —
  write access hardcoded to Scott's agent id via RLS (no real admin-roles
  system yet; revisit if that's ever needed). Upload it from the new
  "perchqr.com" tab in `/app` (hidden from every other agent). Reuses the
  same floating/shrink video component the agent homepage already has,
  recolored to Fieldstone. **Action needed:** run the new `site_settings`
  block appended to the bottom of `supabase/schema.sql` against the live
  project (SQL Editor) — not yet confirmed run as of this entry.

- **2026-09-13 — Self-serve signup built; owner has full access to every
  agent's data.** Reverses the earlier "Scott manually onboards each beta
  agent" scope cut — Scott decided to build real signup now instead.
  - `is_perchqr_owner()` Postgres function (same hardcoded id as
    `site_settings`) is now the bypass condition on every agent-scoped RLS
    policy (agents/properties/testimonials/qr_codes/qr_scans/agent_settings/
    mls_credentials + both storage buckets). Scott can view and edit any
    agent's account, including their MLS connection.
  - `site/signup.html`: name, slug (auto-suggested, live availability check),
    email, password. Handles both Supabase Auth configurations (email
    confirmation on or off) — see the code comments for how.
  - New DB-level guardrails on `agents.slug`: format CHECK + reserved-word
    CHECK, so the reserved-slugs list from "Tenant URL shape" is now actually
    enforced, not just documented.
  - `app.html` gained a **Profile tab** (name/brokerage/phone/contact email/
    license/address/social links/headshot/logo) — required now that signup
    doesn't capture this and Scott can't SQL it in for people at scale — and
    an **owner-only agent switcher** in the header that reassigns the shared
    `AGENT` variable everything already scopes by (uploads included, since
    those path by `AGENT.id` too).
  - **Action needed:** run the updated `supabase/schema.sql` against the live
    project. **Decision needed:** check Supabase Authentication -> Settings ->
    "Confirm email" — off gives instant signup for the beta; on still works,
    just adds an email-confirmation step first.
  - Landing page's public CTA still points at the `mailto:` beta-request
    (kept "private beta" framing intact) rather than linking `/signup`
    directly — Scott can now hand `perchqr.com/signup` straight to anyone
    he's inviting instead of onboarding them via SQL. Revisit if the beta
    ever opens up to public self-serve.

- **2026-09-13 — Three distinct sign-in entry points, plus admin/user
  terminology and video cleanup.**
  - **`/admin`** — new, unlisted, owner-only gate. Authenticates against the
    same Supabase Auth pool as everywhere else (no second credential system),
    but checks the signed-in user's id against `PERCHQR_OWNER_ID` and
    immediately signs out + rejects anyone else before they reach anything.
    Forwards to `/app` on success.
  - **`/app`** — generic sign-in, works for any agent (including the owner).
  - **`/<slug>/access`** — an agent's personal, memorable link to the same
    underlying page. The address bar now auto-syncs to this form on every
    successful sign-in and every agent-switcher change (via `replaceState`,
    no reload) regardless of which of the three doors was used to get in.
  - Renamed every visible "Admin" label in `app.html` to "User Access" (title,
    sign-in heading, header title in all states) — internal ids/classes left
    alone since they're not user-facing.
  - Added a "Remove video" button (Home Page tab + Landing Page Video tab),
    shown only when one's set — previously the only way to change a video was
    to overwrite it, with no way to take one down.
  - Added a "Log in" link to the `perchqr.com` landing nav (`/app`), kept
    visible on mobile unlike the "How it works" anchor.
  - Clarified for Scott: `/app` being publicly reachable was never a security
    gap — it's a login form, not a data view; RLS is what actually protects
    data, same as any normal login page (gmail.com, etc.) being public.

- **2026-09-22 — Clarified: the $50/mo Spark fee was never per-agent.** Scott's
  actual goal was avoiding agents personally paying $50 each — already true
  under the current per-agent-token model (Spark's own FAQ: "$50/mo for each
  MLS you can access... multiple API keys for one MLS will incur only one
  $50/mo charge" — it's a developer-account, per-MLS fee, never multiplied per
  agent; the Own Data plan itself was free/"No MLS Charges" anyway). Real
  remaining goal: reduce the friction of each agent generating/pasting their
  own token. Evidence suggests Scott's Spark developer account is tied to his
  own Flexmls identity (`stg.sbird`) — his approval auto-populated that
  identity without him specifying it, implying he likely can't request "Own
  Data" access on another agent's behalf through his own account. **Email
  drafted (not yet sent) to Washington County BOR/FBS asking directly whether
  PerchQR can request access on an agent's behalf, or whether each agent must
  self-serve under their own Flexmls login** — holding until a response comes
  back before changing anything.

- **2026-10-07 — MLS/FBS replied with three setup options; Option 3 (single
  OIDC key) chosen.** Their summary of the choices:
  1. *Board-wide data plan, filtered on PerchQR's end* — one credential, ~$50/mo,
     needs explicit MLS approval, and likely carries IDX-style compliance for
     the whole board's data. Rejected: costs money and walks back the deliberate
     "no IDX" scope decision.
  2. *"A Broker or Agent's Own Data" per agent* — free, what's already built;
     each agent needs their own key plus agent and MLS approval. Kept as the
     fallback.
  3. *Single OIDC key; each agent clicks a link on PerchQR and approves a
     consent screen after linking their Flexmls account* — free for agent's own
     data, no email approval, no separate Spark account for the agent.
     **Chosen.** Replaces the paste-a-token step with a one-click "Connect your
     Flexmls account." Cost is build effort: OAuth/OIDC authorization redirect,
     a callback Edge Function, and storing/refreshing per-agent access tokens
     (replacing the single static token in `mls_credentials`).
  - Some per-agent consent is unavoidable under every option (Spark's
    two-party authorization); Option 3 just shrinks it to one click on PerchQR.
  - **Follow-up email drafted** (not yet sent) asking how to request the OIDC
    key, what registration needs (redirect URLs, privacy/terms links), cost and
    timeline, scope confirmation (consenting agent's own listings only), token
    lifetimes/rate limits, and whether one key covers other Spark boards later.
    Holding the build until the key's requirements are known.
  - Client ID/secret, once issued, go in Supabase secrets, never the repo.

- **2026-10-22 — "Request beta access" now goes straight to account creation.**
  Scott's call: creating an account *is* the request — no approval step and
  no separate lead form. The landing CTAs (nav, hero, closing band) link to
  `/signup`, which now also collects a required phone number (stored digits-
  only in `agents.phone`, carried through `pending_phone` user metadata for
  the email-confirmation-on path). Signup is therefore open to anyone; add
  gating only if that ever needs to change. A lead-form/modal + `beta_requests`
  table was built and run, then removed the same day — the table can be
  dropped (`drop table public.beta_requests;`). Started a walkthrough of the
  new-agent onboarding experience with a test account for Scott's wife;
  findings to be logged here.

- **2026-10-22 — Per-agent website color.** Reverses the earlier "per-agent
  branding out of scope for the beta" note — Scott asked for it. Profile tab
  has a color picker + hex box, a **Pick from my logo** button (samples the
  most common clearly-colored pixels from the uploaded logo, ignoring
  white/black/gray), and Reset. One color per agent (`agents.brand_color`,
  CHECKed as `#rrggbb`, null = default theme); `Perch.brandPalette()` derives
  hover and tint shades and darkens very light picks so white button text keeps
  4.5:1 contrast. `Perch.applyBrand(agent)` overrides `--maroon` /
  `--maroon-bright` / `--maroon-wash` on `:root` for the agent's homepage and
  listing pages (the theme's legacy variable names are just primary/hover/tint
  roles). Not applied to `/app` itself, which stays PerchQR-branded. Fonts and
  layout remain shared. **Action needed:** run the new `brand_color` ALTER in
  `supabase/schema.sql` — Profile saves fail until the column exists.

- **2026-10-22 — Print-ready QR codes, two sign sizes.** The old 240px QR was
  fine on screen but would blur on a 4×4 ft sign. QR creation now builds the
  code from the QR's module grid (qrcodejs only computes it): whole-pixel
  modules, 4-module white quiet zone, error correction H, center logo at 26%.
  Each save produces three files in the private `qr-codes` bucket, same base
  path: **4×4 ft sign** PNG (~4500px, print the code ≈30" wide), **18×24 in
  yard sign** PNG (~3600px, print ≈12" wide), and a **vector SVG** (sharp at any
  size; best to hand a sign printer). No schema change — `qr_codes.image_url`
  still points at the 4×4 PNG, and the yard PNG / SVG are found by swapping the
  file suffix. The list shows 4×4 ft / 18×24 in / SVG buttons per code. Codes
  saved before this change only have the old small PNG (the new buttons say so
  for those); the printed QR still points at `/q/<id>`, so re-creating a code
  gives a new id — regenerate only for codes not yet printed. Rule of thumb
  surfaced to agents: scanning distance ≈ 10× the code's printed width.

- **2026-11-10 — Possible rename PerchQR -> FlyerBox: research + plan (NOT started;
  discussion only — Scott will decide).** Scott owns `flyerbox.ai` and
  `flyerbox.net`. Opinion given: FlyerBox is the stronger name for agents (the
  flyer box on a yard sign is universally understood; PerchQR needs explaining),
  with caveats: "flyer" can read as paper-only, the phrase is descriptive (weaker
  trademark), `.ai` is less familiar than `.com`.
  - **Checks run (web search + DNS, not authoritative):** no "FlyerBox" product in
    real estate/software found. A UK leaflet-distribution company named FlyerBox
    exists (London; physical distribution, different market/country). A live US
    mark **FLYBOX** (Flybox Services, LLC; Reg. 8043990, classes 9/16/42/45; a
    household-storage app) is the closest conflict — similar name, software
    classes; goods differ but have an attorney/USPTO TESS search confirm before
    committing. `flyerbox.com` is owned by someone else and parked (redirects to a
    `/lander` page) — agents who type `.com` land there. Instagram has an
    `@flyerbox` account (owner unknown); other handles inconclusive.
  - **Domain pick:** `flyerbox.ai` as primary, `flyerbox.net` as a defensive
    redirect, `perchqr.com` kept FOREVER (every printed QR code encodes
    `perchqr.com/q/<id>`). Consider buying `flyerbox.com` if it's ever for sale.
  - **Plan (if we go):** (0) trademark/TESS check, pick domain, new logo/wordmark.
    (1) Prep, no user impact: add the new domains in Netlify + DNS + SSL; set
    Supabase Auth site URL/redirect URLs for both; add a single canonical-origin
    constant so new QR codes always encode the primary domain (today they use
    `window.location.origin`). (2) FBS/Spark: ask to add/replace the OIDC
    redirect URI for the new domain and update the registered company name; keep
    `perchqr.com/oauth/spark/callback` working until confirmed; update the
    `SPARK_OIDC_REDIRECT_URI` secret. (3) Rename text/assets: landing, headers,
    page titles, admin/app/signup, Supabase email templates, favicon/logo,
    PLANNING.md; repo name optional. (4) Cutover: `perchqr.com/*` 301s to the new
    domain keeping paths, with `/q/*` guaranteed to keep resolving. (5) Tell the
    agents (old links keep working), update social handles, file the trademark.
  - **Effort:** text rename + domain setup ~ half a day; FBS change takes days;
    the real work is the logo. Cost of delay grows with every sign printed and
    agent onboarded — decide before the beta agents print at scale.

- **2026-11-09 — Video upload size limit (50 MB).** A 62 MB listing video failed
  to upload; after compressing it uploaded fine, consistent with Supabase's free-plan
  50 MB per-file limit (not independently confirmed in the dashboard). The page
  only said "check your connection," so uploads now show the real reason
  (`friendlyUploadError` in `app.html`), and "50 MB max" is shown next to every
  video upload (property, home page, landing page). Deferred, not started:
  letting agents paste a YouTube link instead of uploading (would avoid the size
  and storage limits; tradeoffs discussed — YouTube branding/related videos,
  embed must stay allowed).

- **2026-11-09 — Admin "To do": location checks + property activity log.**
  **Restore point:** git tag `restore-point-before-location-todo` (commit `cb8d39d`).
  Auto-filled coordinates aren't always exact, so Scott verifies each in Google
  Maps/Earth. New `properties.location_verified_at` / `location_verified_by`
  (schema.sql section 13, run once). Every new property starts unverified; if an
  agent later changes a property's lat/lng or address it goes back to unverified.
  A trigger stops agents from setting the verified fields themselves. `/admin`
  has a **To do** tab (with a count badge on the tab): "Needs checking" lists
  each unverified property — agent, when it was added, Google Maps / Earth links,
  editable latitude/longitude, and **Save and mark verified**; "Verified" lists
  what's been checked (when and by whom). It doubles as a log of when agents add
  listings (newest first). The six properties that existed at launch start as
  "needs checking". Notification is the in-app badge only — email alerts would
  need an email service (not set up). Possible later: an email/text when a new
  property is added, and bulk "mark verified".

- **2026-11-09 — Profile-completion checklist (ideas 1, 2 and 4 from the
  brainstorm).** **Restore point:** git tag `restore-point-before-completion-checklist`
  (commit `0d7a769`); the work is commit `d427817`. No database changes, so undoing
  is code-only: revert that commit (or restore the tag).
  - **Idea 1 — checklist card** at the top of the Properties tab: "Your page is
    X% complete", seven equal items — profile and logo (photo + logo +
    brokerage), Flexmls connected, listings added, testimonials, homepage video,
    QR code created, and a welcome video on every non-Sold listing — with a
    "Next:" action button. Collapses to a one-line "100% complete" message.
    Nothing is required and it can't block anything. Scoring is one shared
    function, `Perch.profileCompletion` in `perch.js`.
  - **Idea 2 — per-listing chips** (Photos / Welcome video / 3D tour) replacing
    the old emoji badges; a "No welcome video" warning chip and an **Add video**
    button (opens the edit form scrolled to the video field) on every non-Sold
    listing without a video.
  - **Idea 4 — admin:** a "Profile complete" bar column in the `/admin` users
    list (hover shows what's missing) and a Profile completion card on each
    user's profile.
  - Notes: the admin queries cap at 5,000 rows per table (fine for the beta; move
    to a counted query/RPC if it ever matters). "Complete" is defined only in
    `profileCompletion` — change the list there.

- **2026-11-04 — Flexmls (Spark OIDC) key issued; sign-in flow built.** FBS
  (Forrest Pinson) created the OIDC key: Redirect URI
  `https://perchqr.com/oauth/spark/callback`, **Role: `idx`**, and said we can
  test with their developer sandbox before full release; "we'll follow up on
  the email thread with Melissa" (WCBOR) — i.e. MLS-side approval may still be
  pending. The OAuth key/secret live ONLY in Supabase secrets
  (`SPARK_OIDC_CLIENT_ID`, `SPARK_OIDC_CLIENT_SECRET`) — never in the repo (it is
  public). Built (nothing active until the setup steps below are done):
  - `supabase/functions/spark-oidc` (new): `start` (returns the Flexmls
    sign-in URL, with an HMAC-signed 10-minute `state` bound to the agent),
    `callback` (verifies state, exchanges the code for tokens server-side,
    reads `my/account`, stores everything), `disconnect`.
  - `site/oauth-callback.html` + `_redirects` rule for `/oauth/spark/callback`:
    reads `code`/`state`, strips them from the URL, hands them to the function
    with the agent's own session, then returns to `/app?mls=connected`.
  - Tokens are stored in a new `spark_oidc_tokens` table with **no client
    policies at all** (only the server functions can read it — Spark's docs say
    never expose tokens to a browser). `mls_credentials` gets `auth_type`
    (`token` | `oidc`) and a placeholder row so the dashboard shows "connected".
    schema.sql section 12.
  - `mls-lookup` now uses the OIDC token for `oidc` agents and refreshes it
    (24h access tokens; refresh tokens rotate) when within 5 min of expiry;
    asks the agent to reconnect if that fails. Spark hosts are overridable via
    secrets `SPARK_AUTH_BASE` / `SPARK_API_BASE` (defaults: sparkplatform.com,
    replication.sparkapi.com) in case the sandbox uses different ones.
  - Dashboard Connect MLS tab: big **Connect your Flexmls account** button
    (+ Disconnect); the paste-a-token form is kept under "Advanced" as the
    fallback. The owner viewing another agent can't connect on their behalf.
  - **Setup notes (2026-11-04):** the new function deployed from the dashboard
    editor got the slug `dynamic-handler` (slugs can't be renamed), so the site
    calls it by that name (`SPARK_OIDC_FN`). First connect attempt failed with
    "Client secret is invalid" — the Supabase secret had to be re-entered;
    after that **Scott's Flexmls connection succeeded** (dashboard shows
    "Connected through Flexmls as Scott Bird"). Next: confirm the MLS lookup
    (photos + 3D tour) works through the OIDC token.
  - **Confirmed (2026-11-09):** Kendall Clements — the first outside agent —
    connected his own Flexmls account through the button and it worked. The
    one-click connection is validated for a second agent/account.
  - **Also 2026-11-09:** homepage/landing videos now size their box to the
    uploaded video's real shape (`fitToVideo` in `perch.js`, `.landscape` /
    `.video-landscape` in `styles.css`), so landscape, portrait and square
    uploads all show uncropped, automatically, for every agent.
  - **Finding (2026-11-04):** with the connection live, looking up Scott's
    Washington County listings (MLS #26-270282, #26-274631 — both Active) returned
    "No listing found … can see 581 listings". Sample listings the connection
    could see were numbered `114807` (Cedar City), `116740` (Enoch), `117411`
    (Hurricane) — **Iron County BOR IDX** data (plain 6-digit numbers), not
    Washington County (`26-######`). So the OIDC key (role `idx`) is attached to
    the Iron County IDX plan, not the Washington County "Own Data" plan. Asked
    Forrest (FBS) which account/plan it's tied to and to link Washington County.
  - **FBS answer (James Richards, 2026-11-05) — SUPERSEDES the one-key-per-MLS
    direction below:** the key was IDX-scoped (each agent's IDX-*eligible*
    listings only, hence the misses). FBS **changed the key's role to Broker Back
    Office**: each authenticated agent now gets **their own listings in any
    status**, with IDX fields plus extra back-office fields (not labeled IDX vs
    non-IDX). Photos are readable with this role; virtual-tour links come as
    standard listing fields. **Other MLSs: no new key needed** — an agent from
    another board just authenticates, agrees to that MLS's Member Terms of Use,
    and grants data access. So one key serves every board. Next: Scott
    reconnects (to be safe, so the token is issued under the new role) and
    re-tests `26-270282` / `26-274631`.
  - **Direction (Scott's idea, 2026-11-04 — superseded above):** keep this key for **Iron County** and
    get a **second key for Washington County** — one OIDC key per MLS. FBS
    allows up to 3 keys per product, one redirect URI each (confirm both may use
    `https://perchqr.com/oauth/spark/callback`). Code change when the second key
    exists: store keys as secrets per board (e.g. a JSON secret mapping board →
    client id/secret) and pick the key from the agent's MLS (`agents.mls_name`,
    from the signup dropdown; ask on the Connect MLS tab if blank); `spark-oidc`
    and `mls-lookup` both need it. Until then Washington County agents use the
    paste-a-token fallback ("Advanced" on Connect MLS). Also confirm with Iron
    County BOR/FBS that serving agents' own listings from the Iron IDX plan is
    allowed (IDX display rules), and that it's not the same plan utahrealestate.us
    relies on in a way that conflicts.
  - **Open questions / follow-ups:** (1) role `idx` — confirm with FBS/Melissa
    what IDX-role access allows and whether IDX display rules apply to what we
    pull; photos/virtual tours may now work since IDX can read photos.
    (2) An IDX-role key can see any IDX listing, so an agent could look up
    someone else's MLS# — consider checking the listing's agent against the
    connected Flexmls member (`my/account`) once we see real responses.
    (3) Which hosts the sandbox uses (docs don't say). (4) Encrypt stored
    tokens (Vault) before scaling. (5) The OAuth secret was pasted into a chat
    session — ask FBS to reissue it if that matters to you.

- **2026-11-04 — Bug fix: every `/q/<id>` QR scan showed "This QR link is
  missing its code."** Found via Kendall's first code. Root cause, present since
  the original port: `q.html` read the id from `?id=`, but Netlify's 200 rewrite
  (`/q/:id -> /q.html?id=:id`) keeps the browser's original URL, so the query
  string never reached the page's JavaScript. `q.html` now reads the id from the
  path (still accepts `?id=`). Codes already printed or saved needed no change —
  they encode `/q/<id>`. Lesson: scan a real code end to end after building the
  QR flow; this slipped through because it was never tested by scanning.
  **Confirmed 2026-11-04:** Scott scanned Kendall's real code after the fix and
  it worked.

- **2026-11-03 — MLS question added to signup.** Optional "Your MLS" dropdown on
  `/signup` (Washington County BOR, Iron County BOR, "Other" → type it in);
  **no state field** (Scott's call — add later if needed). Stored as
  `agents.mls_name` (schema.sql section 11, run once). It's saved in a separate
  step after the account is created, so it can never block signup; the
  email-confirmation fallback in `app.html` carries it via `pending_mls`
  metadata. It pre-fills the Connect MLS tab's MLS name and shows on the admin
  profile page. Purpose: know which MLSs agents come from (expansion demand),
  support, and prefill. The name alone can't identify an MLS or its Spark
  availability — the OIDC flow identifies the MLS from the agent's own Flexmls
  account. Known boards live in the `KNOWN_MLS` list in `signup.html`.

- **2026-11-03 — Account management system (tiers, statuses, archive, audit
  log).** Built from Scott's written spec; framework only — **no tier pricing,
  features, or limits are defined or enforced anywhere.** Restore point before
  this work: git tag `restore-point-2026-11-03` (code only; the SQL below is not
  undone by a revert — see "Undo" at the end of this entry).
  - **Schema (supabase/schema.sql section 10, re-runnable):** `subscription_tiers`
    (stable text id + editable name/description, nullable price/features/limits
    columns reserved for later, `is_active` instead of delete; seeded Beta, Free,
    Tier 1–3), `account_statuses` (active, pending, paused, suspended, canceled,
    archived; each has an `allows_access` flag — only Active is true for now),
    new `agents` columns (`tier_id`, `status_id`, `is_beta_tester`,
    `status_changed_at`, `admin_notes`, `last_activity_at`), and `account_history`
    (permanent audit log: kind, previous/new value, admin id, timestamp, reason).
  - **Tier and status are separate**, and Beta-tester is its own flag, so an
    agent can upgrade to a paid tier and stay marked as a beta tester. Changing a
    status never touches the tier.
  - **Existing accounts migrate as Beta / Active / beta tester**, with one
    starting history row each; nothing overwritten. The old
    `agents.subscription_status` column is left alone and unused.
  - **New signups** start Active / Beta / beta tester, driven by new
    `site_settings.default_signup_*` columns (change them there, not in code).
    Decision: signup stays instant (per the 2026-10-22 "signup is the request"
    call); Pending exists for admins to use but isn't applied automatically.
  - **Changes are atomic:** one RPC, `admin_set_account_field`, updates the
    account and writes the history row in a single transaction; it refuses
    non-owners and refuses to let the owner restrict their own account.
    `touch_my_activity` records "last activity" when an agent opens the dashboard.
  - **Agents can't edit their own tier/status/beta flag/notes** (trigger on
    `agents`; self-inserted rows are forced to the signup defaults). History has
    no insert/update/delete policies and API calls can't alter it; its FK to
    `agents` is `on delete restrict`, so removing an account row can't silently
    erase history.
  - **No account is ever deleted by the admin tooling** — no Delete button;
    Archive is a status. Archived accounts stay searchable and restorable.
  - **Access enforcement:** `app.html` shows a "your account is <status>" screen
    instead of the dashboard for any status with `allows_access = false` (owner
    exempt), and the database write policies on agents, properties, MLS
    credentials, QR codes, testimonials, settings and storage now require an
    access-allowed account. `mls-lookup` also checks it (**redeploy that Edge
    Function manually** to pick this up).
  - **Open question:** a suspended/archived agent's *public* page and listings
    stay online — only dashboard access is blocked. Decide later whether
    suspending/archiving should also hide the public page.
  - **Admin UI (`/admin`):** Users table (name, email, tier, status, beta tester,
    created, last activity, View/Manage) with search (searches all statuses,
    including archived), tier filter, and status tabs — default Active & Pending,
    plus Paused, Suspended, Canceled, Archived accounts, All. Profile view: info,
    tier/status/beta-tester controls with confirmation pop-up (shows user,
    current and new value, extra warning for Suspended/Archived, optional reason),
    Restore to Active, page-address change, listings, notes, history. A separate
    "Subscription tiers" tab edits tier names/descriptions/active flag and adds
    tiers.
  - **Tested 2026-11-03 (Scott, live):** confirmation pop-up + Cancel makes no
    change, real changes saved and appear in History, archive → search → restore
    — all worked. Also verified from the public API: migrated accounts show
    Beta / Active / beta tester and the new tables, history and admin RPC are
    closed to signed-out callers.
  - **Undo:** code → revert commits back to tag `restore-point-2026-11-03`. The
    new tables/columns can stay harmlessly if code is reverted (the old app
    ignores them), but the new write policies and agents trigger would remain —
    to fully undo SQL too, ask for the matching rollback script.

- **2026-11-03 — Admin console + page-address changes.** First outside signup
  (Kendall Clements) ended up at `/551n1400e` and wanted `/kendall`. `admin.html`
  (perchqr.com/admin, owner-only, still unlisted) no longer just forwards to
  `/app`: after the owner signs in it shows an **Agents** list (name, contact,
  join date, page address) with **Change page address** per agent — same
  format/reserved/availability checks as signup, a confirm step, then
  `agents.slug` is updated and any of that agent's `qr_codes.url` destinations
  on the old slug are rewritten to the new one (QR images encode `/q/<id>`, so
  printed signs are unaffected). A "User dashboard" button still goes to `/app`.
  No schema change — the existing owner RLS on `agents`/`qr_codes` covers it.
  The old address simply 404s after a change (no redirect/slug history kept —
  add one if agents start sharing links before settling on a name). Signup's
  label is now "Set up your URL name (web page address)". Agents still can't
  change their own slug.

- **2026-10-23 — Landing page video script finalized** (~35 sec, no presenter
  name so any agent could say it; deliberately no conversion/results claims
  while the beta is unvalidated; location line says "standing at" because the
  match radius is 100 ft):
  > Welcome to PerchQR, and thank you for stopping by. We turn your MLS listing
  > into a beautiful listing page, where you introduce yourself and the property
  > in a short personal video, so buyers get to know you before they ever call.
  > Put one QR code on every sign. When a buyer scans it and shares their
  > location, they go straight to the home they're standing at. The code never
  > changes, so you never reprint your signs for each new listing, saving you
  > real money. We're in beta, so click Create account and try it.

  Upload via `/app` → Landing Page Video (owner-only). Film vertical; the
  landing box crops top/bottom (4:5 over a 9:16 video).

- **2026-10-23 — Nearest-listing smart-match restored on QR scans.** Reverses the
  2026-09 port-time cut. `q.html`: a code whose destination is not a specific
  listing page (e.g. the agent homepage) waits up to 8s for the visitor's
  location (high accuracy), finds the agent's nearest property with coordinates,
  and redirects to its listing if within 100 ft (30.48 m; tightened from 200 m);
  scan coordinates are saved only when that match happens. No permission, timeout, or no
  listing within 100 ft falls back to the code's destination, which is always the
  agent's own landing page (perchqr.com/<slug>) — a bare perchqr.com is rewritten
  to it in both the QR form and `q.html`. Codes pointing at
  a specific listing never reroute (their scans still log coordinates as before).
  Landing video script may now claim "one code, nearest listing" — only for
  visitors who allow location.

- **2026-10-23 — Flexmls/Spark (FBS developer support) replied on the OIDC key.**
  (The reply came from FBS developer support, not the MLS itself.) They need
  (1) the **Redirect URI(s)** — one URI per key, up to three keys per product
  (Development / Staging / Production) — and (2) which of Scott's two Spark
  Developer accounts to tie the key to (**ScottBird17** or **ScottBird8**;
  permanent). Docs: sparkplatform.com/docs/authentication/openid_connect_authentication
  — authorize `sparkplatform.com/openid/authorize`, token
  `sparkplatform.com/openid/token`; code exchange needs the client secret, so it
  must run server-side; access tokens last 24h, refresh tokens rotate on each
  refresh; HTTPS required for OIDC requests (redirect URI https "encouraged").
  - **Planned redirect URI:** `https://perchqr.com/oauth/spark/callback` — a
    static page on our own domain that reads `code`/`state` and posts them,
    with the agent's Supabase session, to an Edge Function that does the token
    exchange and stores the tokens. (Avoids registering the `supabase.co`
    domain and avoids disabling JWT verification on the function.)
  - **Account choice:** use the one *not* behind utahrealestate.us, so the
    production site's credentials stay isolated (per the 2026-09-09 decision).
    Which of the two that is wasn't recorded in the repo — **found in Scott's
    email (2026-11-03): `ScottBird17` is the PerchQR account.** Spark's welcome
    emails show `ScottBird8` created 2026-09-04, with the Iron County BOR IDX
    plan (utahrealestate.us's feed) approved ~2.5 hours later; `ScottBird17`
    created 2026-09-11, with the Washington County "Own Data" plan approved
    ~77 minutes later (the PerchQR setup). The approval emails don't name the
    requesting account, so this is by timing + the 2026-09-11 plan — confirm by
    logging in. **Caveat:** on 2026-10-23 Scott couldn't log in to
    `ScottBird17` (password reset wasn't taking; FBS support suggested another
    browser / disabling password managers); no resolution in email yet. He
    needs to be able to log in to the account that will own the OIDC key.
    **Update 2026-11-03:** Scott can now log in to `ScottBird17`, and replied to
    James with the Production redirect URI, the account choice, and the
    photos/virtual-tour permission question. **Connecting agents to the MLS
    (OIDC) is the top priority — waiting on FBS's answer before building.**
    Meanwhile Kendall Clements (first outside agent) has no MLS connection;
    options for him are the manual token steps (developer account → Datamart
    Own Data plan → paste token in Connect MLS) or manual property entry.
  - Client ID/secret go in Supabase secrets, never the repo.

### QR Codes: Edit button (2026-11-11)

- Each saved QR code now has an **Edit** button (label + destination) in
  `app.html`. The code's picture encodes `/q/<id>`, so changing the destination
  redirects the same printed code — no reprint. Destinations typed as a path
  (`/kendall/listing?id=…`) get the site address added; a bare `perchqr.com`
  becomes the agent's own landing page. Restore point:
  `restore-point-before-qr-edit`. Tested with stubbed data, not a real save.

### Business-card page — Scott's account only (2026-11-11)

- **What:** `site/card.html`, reached at `perchqr.com/scott-bird/card`. A
  phone-first "about me" page for the QR code on Scott's business cards: photo,
  name/brokerage/license, review count, Call/Text/Email buttons, a "Save to my
  contacts" button (builds a `.vcf` in the browser), the home welcome video,
  current listings, three random reviews, contact links.
- **Scott only, on purpose:** a single explicit `_redirects` rule for
  `/scott-bird/card`; other agents' `/<slug>/card` is NOT routed. If it becomes a
  feature for everyone, change the rule to `/:slug/card` and make the page's
  `SLUG` come from the URL.
- **Text Scott controls:** `ABOUT` (paragraphs) and `HIGHLIGHTS` (bullets) at the
  top of the script in `card.html`. Both start empty and the sections stay
  hidden until filled — nothing was invented on his behalf.
- **QR smart-match:** `q.html` now treats `/card` like `/listing` — a code that
  points at the card always goes to the card, never to the nearest listing.
- To use: QR Codes tab -> create a code with destination `/scott-bird/card`.

---

## Open Questions

Resurface these at the start of planning sessions until each is closed.

### Domain / brand
1. ~~Product name + domain~~ — **DECIDED: PerchQR / `perchqr.com`** (see log).
2. ~~"Realtor" in the name~~ — avoided.
3. ~~One domain or two?~~ — one domain; app at `perchqr.com/app` for v1.
4. ~~Tenant URL shape~~ — **DECIDED: path-based `perchqr.com/<slug>`** (see log).
5. **"QR" in the name — mitigation.** Name is locked, but treat "QR" as a
   descriptor, not a wall: keep product copy/architecture open to NFC taps and
   short links so the brand can outlive the acronym.
6. **Pre-launch legal checks** (before signs/LLC): USPTO TESS "perch" classes
   9/35/36/42, Utah business-name registry. Grab `@perchqr` socials.

### Product / architecture
**RESOLVED (2026-11-05) — the OIDC key was changed to Broker Back Office; Scott
reconnected through Flexmls and the lookup of #26-270282 pulled in everything
(photos and tour included). A listing owned by another agent (#26-274631,
Kendall's) correctly returned "not found" for Scott — confirms lookups are
scoped to the signed-in agent's own listings. Next: Kendall connects with his own
Flexmls login.
Original issue — MLS autofill didn't bring in photos or the Matterport
tour (2026-11-03):** Scott's Own Data token returns listing details but the photos call
(`/v1/listings/{id}/photos`) fails with "You do not have permission to perform
the requested action" (Spark/FBS side, likely a data-plan/key permission); the
virtual-tour lookup returned no Matterport link (its errors are swallowed, so
it could be the same permission or simply no tour on that listing). Photos and
the tour are added by hand for now. **Next step:** ask FBS (James Richards)
to enable photo + virtual-tour access on the key and on the future OIDC key —
question drafted for the OIDC thread. Once granted, re-test with MLS #26-270282
(note: that number is shared by two listings; the lookup now prefers the Active
one and warns). Consider surfacing tour errors in the "Heads up" note too.
7. ~~Billing model~~ — **DECIDED: none for the beta** (free / Stripe Payment Link).
   Real billing at launch decision — see log.
8. ~~MLS access~~ — **RESOLVED for the beta:** per-agent credentials, confirmed
   working (see 2026-09-11 RESOLVED entry). Each beta agent self-serves a free
   Washington County BOR "Own Data" token and pastes it into PerchQR's
   "Connect your MLS" step. Remaining build task, not a decision: implement that
   connect screen + encrypted per-agent token storage (not a launch-blocking
   research item anymore). Deferred to real expansion: other MLSs may not offer
   a free self-serve plan like this one — revisit vendor/Datamart process then.
9. ~~Tenant isolation~~ — **DECIDED: single Supabase project + RLS on `agent_id`**
   (see log for the concrete schema/policy shape).
10. ~~Hosting~~ — **DECIDED: Netlify, one static site, GitHub CI** (see log).
11. **Custom domains per agent** — later add-on, not beta.

### Build progress
- **2026-09-11 — [supabase/schema.sql](supabase/schema.sql) written.** Extends the
  reference `schema.sql` (Scotts QR) with `agents` + `mls_credentials` tables and
  `agent_id` on every tenant table, per the "Tenant isolation" decision above.
  Notable calls made while writing it (flag if any feel wrong):
  - `properties.id` stays a text slug (existing random-suffix scheme), not moved
    to UUID — collision risk negligible at beta scale.
  - Scan-notification email webhook (Apps Script trigger) **dropped** — was
    Scott-specific, real per-agent setup friction, not needed for the beta.
    `qr_scans` still records analytics.
  - `mls_credentials.access_token` is RLS-protected but not encrypted at rest —
    TODO before scaling past a trusted beta: move to Supabase Vault.
  - Not yet written: the "Connect your MLS" admin screen, the multi-tenant
    version of `admin.html`/`index.html`/etc., and the `/q/<id>` redirector page.

- **2026-09-11 — Public site files ported.** [site/index.html](../site/index.html),
  [site/listing.html](../site/listing.html), [site/q.html](../site/q.html),
  [site/assets/perch.js](../site/assets/perch.js) (renamed/genericized from the
  reference `site.js`/`Stratum` object — every agent-identity constant is now a
  parameter), [site/assets/styles.css](../site/assets/styles.css) (ported
  near-verbatim, one shared theme for all beta agents),
  [site/assets/supabase-client.js](../site/assets/supabase-client.js)
  (placeholder — needs real project URL/anon key once the Supabase project
  exists), [site/_redirects](../site/_redirects) (tenant routing).
  - **Routing gotcha handled:** pages reached via a Netlify rewrite keep the
    browser's original URL, so every asset/link path had to become absolute
    (`/assets/...`, `/${slug}/listing?id=...`) rather than relative — see the
    comment at the top of `perch.js`.
  - Two more schema columns added while porting: `agents.google_url`,
    `agents.facebook_url` (optional social buttons in the contact section).
    `agents.phone` documented as digits-only; `perch.js` formats for display.
  - **Deliberate cuts from the reference site** (flag if any should come back):
    no `/scott`-style personal "About" marketing page; no hamburger link to an
    agent's own external MLS search tool (that was Scott-specific); no
    "search all listings" banner on the homepage (no IDX, per scope); no
    geolocation "nearest listing" smart-match on scan (`q.html` does a simple
    id → log → redirect instead, per the redirector-ID decision) — a fast,
    best-effort geolocation *tag* on the scan log is still there, just no
    matching logic.
  - **Not yet ported:** `admin.html` (the CRUD panel, biggest file — next up),
    the "Connect your MLS" screen.

- **2026-09-11 — Supabase project created and wired up.** Project ref
  `qesnpdmwurszqljlbmkp` (`https://qesnpdmwurszqljlbmkp.supabase.co`).
  [site/assets/supabase-client.js](../site/assets/supabase-client.js) now has
  the real URL + publishable key (Supabase's current name for the anon key —
  same thing). Note the dashboard has moved to "Publishable/Secret key"
  naming; secret key = old service_role, never goes client-side.
  `supabase/schema.sql` has been run against this project — tables exist.

- **2026-09-11 — Admin panel ported.** [site/app.html](../site/app.html) (served
  at `/app`, added to `_redirects`) — full CRUD, scoped to the signed-in
  agent throughout. Tabs: **Properties** (add/edit/delete, quick status,
  hero/gallery/video upload, geocoding, PDF-listing-sheet best-effort import,
  MLS# lookup), **Connect MLS** (new — paste the Spark access token from the
  per-agent self-serve flow; status card shows connected/not), **Testimonials**,
  **Home Page** (welcome video only), **QR Codes** (generate/save/download with
  optional center logo + scan log). Auth now checks for an `agents` row after
  sign-in and shows a clear "not set up yet" state if none exists (no self-serve
  signup in the beta, per the earlier scope cut).
  - **Cut from the reference admin:** the "Scott Page" tab (no About page in
    scope) and "Import Backup" tab (legacy localStorage-migration flow, not
    relevant to a fresh multi-tenant product).
  - Storage upload paths now prefixed with `${AGENT.id}/...` throughout,
    matching the RLS policies in `schema.sql`.
  - QR generation simplified: every code now encodes `<origin>/q/<qr_codes.id>`
    unconditionally (no more locate.html special-casing), matching the
    redirector decision.

- **2026-09-11 — [supabase/functions/mls-lookup/index.ts](../supabase/functions/mls-lookup/index.ts)
  rewritten for per-agent tokens.** Instead of one project-wide
  `SPARK_ACCESS_TOKEN` secret, it authenticates the caller, looks up *their*
  row in `mls_credentials` via the service role, and uses that agent's own
  token for the Spark call — matching the per-agent credential model.
  **Not yet deployed** — needs `supabase functions deploy mls-lookup` via the
  Supabase CLI (requires `supabase login` + `supabase link`, which — like
  project creation — needs Scott to do the auth step himself).

- **2026-09-11 — MLS lookup end-to-end confirmed working; two real bugs found and fixed.**
  1. **Client-side bug:** `sb.functions.invoke()` puts a generic "non-2xx
     status code" message on `error` for ANY Edge Function error response —
     the actual `{error: "..."}` body has to be read off `error.context`
     (the raw Response). Without this fix, every failure mode (not connected,
     no listing found, Spark failure) showed the same unhelpful generic
     message. Fixed in `app.html`'s MLS lookup handler.
  2. **Operator error, not a code bug:** the token saved in Connect MLS was
     Spark's generic developer sandbox/demo token (auto-issued at developer
     registration, before any real MLS approval) — NOT the real Washington
     County BOR token from the earlier Datamart approval. Symptom was
     deceptive: real API calls succeeded and returned real-looking data (an
     unfiltered query returned 5 listings), just from Spark's nationwide demo
     dataset (one sample was in Great Falls, MT) rather than actual Washington
     County listings. **Lesson for future MLS connections:** verify a newly
     connected MLS by checking that a returned listing's *city* actually
     matches the expected board, not just that the API call succeeds.
  - `mls-lookup` also now retries with dashes stripped from the MLS number
    (Spark doesn't always store them), kept as a permanent improvement.
  - **Deployment reminder:** pushing to GitHub only redeploys the Netlify
    static site — Supabase Edge Functions need a **separate manual redeploy**
    every time `supabase/functions/mls-lookup/index.ts` changes (via the
    Supabase dashboard's function editor, copy-paste, since no CLI/GitHub
    Actions link exists yet for this).
  - First real property successfully added via the admin panel using MLS
    #26-274631 (Washington County).

- **2026-09-11 — Live end-to-end: GitHub -> Netlify -> Supabase confirmed working.**
  - GitHub repo: `github.com/ScottBird8/PerchQR` (note: capital-letter `PerchQR`,
    unlike the lowercase `perchqr.com` domain/brand — cosmetic only, doesn't
    need fixing).
  - Netlify project `perchqr` (`perchqr.netlify.app`), deploying from that repo,
    publish directory `site`. **Netlify's "Visitor access" must stay set to
    Public** — it defaults to Team-only ("Team protection"), which silently
    blocks every visitor (including QR scanners) behind a Netlify login. Check
    this after any new Netlify project creation.
  - Scott's own Auth user + `agents` row created (`id`
    `72158799-b0f4-47c9-ac2a-45ffe52db1df`, slug `scott-bird`).
  - Verified live: `perchqr.netlify.app/scott-bird` renders his real homepage
    from Supabase; `perchqr.netlify.app/app` shows the admin sign-in gate.
  - **Custom domain connected.** `perchqr.com` (A record -> `75.2.60.5`) and
    `www.perchqr.com` (CNAME -> `perchqr.netlify.app`) added in GoDaddy DNS and
    in Netlify's Domain management. Confirmed working directly against
    Netlify's IP (HTTP 200, valid SSL) — just waiting on DNS propagation to
    finish on some resolvers (Google's 8.8.8.8 already correct; Scott's local
    ISP resolver was still stale as of this check). No further action needed,
    just time.
  - `mls-lookup` Edge Function still not deployed (needs `supabase login` +
    `supabase functions deploy`, same "needs Scott's own login" constraint).

### All beta-blocking questions are now closed.
Open items left are all either pre-launch legal checks (#6), post-beta expansion
questions (#5, and the "QR" mitigation), or not needed for the beta at all
(#11). Nothing above blocks starting the build.
