-- Requires at least one auth user; this will no-op until a user exists.
with existing_user as (
  select id from auth.users limit 1
)
insert into public.assignments (user_id, status, name, course, type, due_at)
select id, 'Not Started', 'Graph Theory Problem Set', 'MATH 425', 'Homework', timezone('utc', now()) + interval '2 days'
from existing_user
union all
select id, 'In Progress', 'Operating Systems Report', 'CSE 451', 'Report', timezone('utc', now()) + interval '5 days'
from existing_user
union all
select id, 'Completed', 'Modern Poetry Essay', 'ENG 210', 'Essay', timezone('utc', now()) - interval '1 day'
from existing_user;
