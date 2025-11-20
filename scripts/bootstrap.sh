#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install from https://brew.sh first." >&2
  exit 1
fi

brew bundle --file=- <<'BREW'
brew "swiftlint"
brew "supabase/tap/supabase"
BREW

if [ ! -f Config/Environment.plist ]; then
  cp Config/Environment.plist.example Config/Environment.plist
  echo "Created Config/Environment.plist from example"
fi

if [ ! -f supabase/config/supabase.env ]; then
  cp supabase/config/supabase.env.example supabase/config/supabase.env
  echo "Created supabase/config/supabase.env"
fi

echo "Bootstrap complete. Update Config/Environment.plist with Supabase credentials."
