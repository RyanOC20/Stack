create extension if not exists "pgcrypto";

do $$
begin
  if not exists (select 1 from pg_type where typname = 'assignment_status') then
    create type public.assignment_status as enum ('Not Started', 'In Progress', 'Completed');
  end if;
  if not exists (select 1 from pg_type where typname = 'assignment_type') then
    create type public.assignment_type as enum ('Homework', 'Report', 'Essay', 'Presentation', 'Quiz', 'Exam');
  end if;
end $$;

-- Drop the text defaults first: Postgres can't auto-cast a text default
-- expression to the new enum type during the column type change.
alter table public.assignments
  alter column status drop default,
  alter column type drop default;

alter table public.assignments
  alter column status type public.assignment_status using status::public.assignment_status,
  alter column type type public.assignment_type using type::public.assignment_type;

-- Re-add the defaults, now interpreted in the enum's context.
alter table public.assignments
  alter column status set default 'Not Started',
  alter column type set default 'Homework';

alter table public.assignments
  add column if not exists user_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'assignments_user_id_fkey') then
    alter table public.assignments
      add constraint assignments_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

alter table public.assignments
  alter column user_id set default auth.uid();

do $$
begin
  if exists (select 1 from public.assignments where user_id is null) then
    raise exception 'assignments.user_id contains nulls; backfill before enforcing not null.';
  end if;
end $$;

alter table public.assignments
  alter column user_id set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'assignments_name_nonempty') then
    alter table public.assignments
      add constraint assignments_name_nonempty check (char_length(trim(name)) > 0);
  end if;
end $$;

create or replace function public.set_assignment_user_id()
returns trigger as $$
begin
  new.user_id := auth.uid();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_assignment_user_id on public.assignments;
create trigger set_assignment_user_id before insert on public.assignments
for each row execute function public.set_assignment_user_id();

alter table public.assignments enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Assignments select own') then
    create policy "Assignments select own" on public.assignments
      for select using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Assignments insert own') then
    create policy "Assignments insert own" on public.assignments
      for insert with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Assignments update own') then
    create policy "Assignments update own" on public.assignments
      for update using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Assignments delete own') then
    create policy "Assignments delete own" on public.assignments
      for delete using (user_id = auth.uid());
  end if;
end $$;

drop index if exists assignments_due_at_idx;
drop index if exists assignments_status_idx;
drop index if exists assignments_course_idx;

create index if not exists assignments_user_due_at_idx on public.assignments (user_id, due_at);
create index if not exists assignments_user_status_idx on public.assignments (user_id, status);
create index if not exists assignments_user_course_idx on public.assignments (user_id, lower(course));
