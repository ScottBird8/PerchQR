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
