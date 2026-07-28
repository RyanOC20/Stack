-- Import provenance for the AI ingestion feature: one row per extraction job
-- (screenshot / photo / pasted URL / pasted text). Mirrors the hardening style
-- of 0003_harden_assignments.sql: idempotent, RLS on, per-user policies.

create table if not exists public.imports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid(),
    source_type text not null default 'screenshot',
    source_ref text,
    status text not null default 'extracted',
    created_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'imports_user_id_fkey') then
    alter table public.imports
      add constraint imports_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'imports_source_type_valid') then
    alter table public.imports
      add constraint imports_source_type_valid
      check (source_type in ('screenshot', 'photo', 'url', 'text'));
  end if;
end $$;

create or replace function public.set_import_user_id()
returns trigger as $$
begin
  new.user_id := auth.uid();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_import_user_id on public.imports;
create trigger set_import_user_id before insert on public.imports
for each row execute function public.set_import_user_id();

alter table public.imports enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Imports select own') then
    create policy "Imports select own" on public.imports
      for select using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Imports insert own') then
    create policy "Imports insert own" on public.imports
      for insert with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Imports update own') then
    create policy "Imports update own" on public.imports
      for update using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Imports delete own') then
    create policy "Imports delete own" on public.imports
      for delete using (user_id = auth.uid());
  end if;
end $$;

create index if not exists imports_user_created_at_idx on public.imports (user_id, created_at desc);

-- Let a confirmed assignment trace back to the extraction it came from.
alter table public.assignments
  add column if not exists import_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'assignments_import_id_fkey') then
    alter table public.assignments
      add constraint assignments_import_id_fkey foreign key (import_id)
      references public.imports(id) on delete set null;
  end if;
end $$;

-- Private Storage bucket holding uploaded screenshots/photos, scoped so each
-- user can only touch objects under their own "{user_id}/…" prefix.
insert into storage.buckets (id, name, public)
values ('imports', 'imports', false)
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Import objects select own') then
    create policy "Import objects select own" on storage.objects
      for select using (
        bucket_id = 'imports'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Import objects insert own') then
    create policy "Import objects insert own" on storage.objects
      for insert with check (
        bucket_id = 'imports'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Import objects delete own') then
    create policy "Import objects delete own" on storage.objects
      for delete using (
        bucket_id = 'imports'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
end $$;
