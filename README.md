# RealtorQR

A multi-tenant SaaS platform letting any realtor sign up and get their own
QR-driven listing site (`realtorqr.com/<agent-slug>`), with the live MLS
search, admin panel, QR code generation, and property pages that currently
exist only for Scott Bird on `utahrealestate.us`.

This is a fresh project, not a fork — but it's built by generalizing patterns
already proven out in production on two sibling single-tenant sites:

- `C:\Users\scott\Scotts QR` — utahrealestate.us. Source of the core
  patterns: Supabase (Postgres + Auth + Storage) backend, the admin CRUD
  panel, QR generation with center-logo embedding, the property page's
  video/gallery UI, and the original Spark API (MLS) integration.
- `C:\Users\scott\Brian Head Real Estate` — brianheadrealestate.com. Source
  of the live cross-brokerage MLS search pattern (Supabase Edge Function
  proxying Spark API, listing detail modal, redaction/photo handling).

Reference those two codebases directly when porting a pattern here — don't
re-derive them from scratch.

## What's different here (multi-tenant, not single-agent)

- Every data table carries an `agent_id`; Postgres Row Level Security scopes
  each authenticated agent to their own rows.
- The public site resolves `<agent-slug>` from the URL path into an
  `agent_id` before querying — one dynamic template serving every tenant,
  same as the single-tenant sites already do for their one agent.
- Each agent connects their own MLS/Spark API credentials during onboarding
  — MLS/IDX data-license access is per-board and per-agent and cannot be
  resold or shared across tenants in different markets.
- New pieces with no single-tenant equivalent: signup/slug-claim flow,
  Stripe billing, encrypted per-tenant API credential storage.

See the phased build plan for sequencing.
