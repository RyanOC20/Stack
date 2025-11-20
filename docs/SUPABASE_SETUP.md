# Supabase Setup

## Configure Environment
1. Copy `supabase/config/supabase.env.example` to `.env` and fill in your Supabase project reference, anon, and service keys.
2. Export the variables in your shell session or let the Supabase CLI load them automatically.

## Start Local Stack
```
supabase start
```
This runs a local Postgres + APIs container.

## Apply Migrations
```
supabase db reset
```
This command stops/starts the database and applies migrations stored in `supabase/migrations/`.

## Seed Data
```
supabase db remote commit
psql < supabase/seed/sample_data.sql
```
For local testing, you can also run:
```
supabase db reset --seed supabase/seed/sample_data.sql
```

## Generate Client Types
Use the helper script to generate Swift DTOs from Supabase if you decide to rely on the codegen pipeline:
```
./scripts/generate-supabase-types.sh
```

## Deploying
1. Commit schema changes.
2. Push to `main`. CI ensures the macOS target builds.
3. Use `supabase db push` to deploy migrations to your hosted Supabase project.
