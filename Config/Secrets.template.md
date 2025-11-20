# Secrets Management

1. Copy `Config/Environment.plist.example` to `Config/Environment.plist` and fill in Supabase URL + anon key.
2. For CI, add `SUPABASE_URL` and `SUPABASE_ANON_KEY` as encrypted repository secrets.
3. Never commit real credentials. The example/template files exist so the project builds without secrets.
