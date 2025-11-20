# Architecture

Stack follows a lightweight MVVM approach with SwiftUI views, observable view models, and a thin data layer that talks to Supabase.

## Layers
1. **UI (SwiftUI Views)** – Located in `Stack/Features`. Views are stateless except for transient editing state; they bind to view models for data mutations.
2. **View Models** – `AssignmentsListViewModel` orchestrates loading assignments, handling inline edits, deletions, quick-add, and undo operations.
3. **Services** – `Services/Supabase` hosts network-bound repositories. For now the Supabase repository is a stub that returns mock data, but the structure matches production usage.
4. **Models** – Domain models live under `Stack/Models`, keeping UI and data representations consistent and Codable.
5. **Styling** – Centralized typography, colors, and spacing ensure the dark, minimal appearance is consistent.

## Data Flow
```
View -> ViewModel -> Repository -> Supabase -> Repository -> ViewModel -> View
```
- Views send user intents (edits, deletes) to the view model.
- The view model updates local state instantly for snappy UX and asynchronously persists via the repository.
- Undo operations are managed with a simple stack storing the last deleted assignment.

## Keyboard Handling
`KeyboardShortcutsHandler` captures scene-level shortcuts (Cmd+N, Cmd+Z, Delete, Enter, arrows) and forwards them to the view model. SwiftUI's focus + move command APIs handle arrow navigation while maintaining inline editing for text fields.

## Supabase Integration
- `SupabaseClient` configures the official Supabase Swift SDK using credentials from `Config/Environment.plist`.
- `AssignmentRepository` performs CRUD via Supabase RPC or direct table calls.
- DTO structs map database rows to `Assignment` models.

## Future Work
- Offline cache using `Persistence/LocalCache`.
- Course normalization (dedicated table).
- Richer undo/redo stack and multi-row selection.
- Unit tests targeting each ViewModel action, plus UI automation covering keyboard flows.
