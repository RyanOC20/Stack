# API Schema

## assignments Table
| Column     | Type        | Notes                                                               |
|------------|-------------|---------------------------------------------------------------------|
| id         | uuid        | Primary key (default gen_random_uuid)                               |
| user_id    | uuid        | FK to auth.users(id); required for RLS                              |
| status     | enum        | Enum: Not Started / In Progress / Completed                         |
| name       | text        | Assignment title (non-empty)                                        |
| course     | text        | Course code or name (defaults to empty string)                      |
| type       | enum        | Enum: Homework / Report / Essay / Presentation / Quiz / Exam        |
| due_at     | timestamptz | Due date/time                                                       |
| created_at | timestamptz | Defaults to timezone('utc', now())                                  |
| updated_at | timestamptz | Trigger updates on each write                                       |

### RLS Policies
- RLS is enabled on `assignments`.
- `select/insert/update/delete` policies restrict access to rows where `user_id = auth.uid()`.

### REST Endpoints (Supabase)
- Auth: `POST /auth/v1/signup` and `POST /auth/v1/token?grant_type=password` with `{ email, password }`.
- Assignments:
  - `GET /rest/v1/assignments?select=*&order=due_at`
  - `POST /rest/v1/assignments?on_conflict=id` with `Prefer: return=representation,resolution=merge-duplicates` (body includes `user_id`).
  - `DELETE /rest/v1/assignments?id=eq.<uuid>`

## RPC / Views
None in MVP. Future releases may add RPCs for summary stats.

## Data Contracts
`AssignmentDTO` mirrors the Postgres columns with snake_case mapping (including optional `user_id`), while `Assignment` represents the domain model in camelCase. `AssignmentRepository` converts between them and encapsulates Supabase networking.
