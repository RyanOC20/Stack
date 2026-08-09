-- Per-user daily quota for the AI ingestion Edge Function, protecting the paid
-- model key from runaway/abusive use. Same hardening style as 0003/0004:
-- idempotent, RLS on, per-user access. The Edge Function calls
-- increment_extraction_usage() before each extraction and returns 429 when the
-- limit is reached.

create table if not exists public.extraction_usage (
    user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    day date not null default (timezone('utc', now()))::date,
    count integer not null default 0,
    primary key (user_id, day)
);

alter table public.extraction_usage enable row level security;

-- Read-only visibility of your own usage. Writes go exclusively through the
-- SECURITY DEFINER function below, so no insert/update/delete policies exist.
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Extraction usage select own') then
    create policy "Extraction usage select own" on public.extraction_usage
      for select using (user_id = auth.uid());
  end if;
end $$;

-- Atomically records one extraction for the caller (today, UTC) if under the
-- limit. Returns the new count, or -1 when the limit is already reached (no
-- increment applied). Runs as definer but keys off auth.uid(), so a caller can
-- only ever affect their own row.
create or replace function public.increment_extraction_usage(daily_limit integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    today date := (timezone('utc', now()))::date;
    new_count integer;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;

    insert into public.extraction_usage (user_id, day, count)
    values (auth.uid(), today, 1)
    on conflict (user_id, day)
      do update set count = extraction_usage.count + 1
      where extraction_usage.count < daily_limit
    returning count into new_count;

    -- No row returned => conflict update was blocked by the limit guard.
    if new_count is null then
        return -1;
    end if;

    return new_count;
end;
$$;

revoke all on function public.increment_extraction_usage(integer) from public;
grant execute on function public.increment_extraction_usage(integer) to authenticated;
