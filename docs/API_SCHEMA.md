# API Schema

## assignments Table
| Column     | Type        | Notes                                  |
|------------|-------------|----------------------------------------|
| id         | uuid        | Primary key (default gen_random_uuid) |
| status     | text        | Enum: Not Started / In Progress / Completed |
| name       | text        | Assignment title                        |
| course     | text        | Course code or name                     |
| type       | text        | Enum: Homework/Report/Essay/Presentation/Quiz/Exam |
| due_at     | timestamptz | Due date/time                           |
| created_at | timestamptz | Defaults to NOW()                       |
| updated_at | timestamptz | Updated via trigger or client           |

## RPC / Views
None in MVP. Future releases may add RPCs for summary stats.

## Data Contracts
`AssignmentDTO` mirrors the Postgres columns with snake_case mapping, while `Assignment` represents the domain model in camelCase. Use `AssignmentRepository` to convert between them and to encapsulate Supabase networking.
