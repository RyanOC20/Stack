#!/usr/bin/env bash
set -euo pipefail

if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI missing. Install via brew install supabase/tap/supabase" >&2
  exit 1
fi

supabase gen types typescript --project-id "${SUPABASE_PROJECT_ID:-}" --schema public > supabase/generated-types.ts

echo "Generated supabase/generated-types.ts (used for reference / potential tooling)."
