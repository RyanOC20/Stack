insert into public.assignments (status, name, course, type, due_at)
values
  ('Not Started', 'Graph Theory Problem Set', 'MATH 425', 'Homework', timezone('utc', now()) + interval '2 days'),
  ('In Progress', 'Operating Systems Report', 'CSE 451', 'Report', timezone('utc', now()) + interval '5 days'),
  ('Completed', 'Modern Poetry Essay', 'ENG 210', 'Essay', timezone('utc', now()) - interval '1 day');
