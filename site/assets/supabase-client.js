// Supabase project connection. The publishable key (Supabase's current name
// for what used to be called the "anon" key — same thing, drop-in compatible
// with supabase-js) is safe to ship in client-side code — it's constrained by
// the RLS policies in supabase/schema.sql (public read on agents/properties/
// testimonials/agent_settings; authenticated-and-owner-only for writes;
// mls_credentials has no anon access at all). Never put the secret key
// (formerly "service_role") here.
const SUPABASE_URL = 'https://qesnpdmwurszqljlbmkp.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_KUo1hETsE6KzOUymY7cT2w_kgOOl48M';

// `supabase` here is the global namespace injected by the CDN script
// (https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2), which must be
// loaded before this file. `sb` is the actual client every page uses.
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
