create extension if not exists "uuid-ossp";

create table if not exists public.assignments (
    id uuid primary key default gen_random_uuid(),
    status text not null default 'Not Started',
    name text not null,
    course text not null default '',
    type text not null default 'Homework',
    due_at timestamptz not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists assignments_due_at_idx on public.assignments (due_at);
