create index if not exists assignments_course_idx on public.assignments (course);
create index if not exists assignments_status_idx on public.assignments (status);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$ language plpgsql;

create trigger assignment_updated_at before update on public.assignments
for each row execute function public.set_updated_at();
