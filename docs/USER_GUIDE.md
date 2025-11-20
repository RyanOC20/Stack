# Stack User Guide

Stack is a dark, keyboard-first macOS assignments tracker. This guide highlights the essential workflows.

## Core Concepts
- **Single view**: All assignments appear in one scrolling table with columns for status, name, course, type, and due date.
- **Quick add**: The first row is always a new-assignment row. Start typing to create a draft, then press `Enter` to save.
- **Keyboard-driven**: Navigate rows with `↑/↓`, edit with `Enter`, delete with `Delete`, undo deletes via `Cmd+Z`, and jump to quick add using `Cmd+N`.

## Editing Assignments
1. Select a row by clicking or using arrow keys.
2. Press `Enter` to edit the name inline. Press `Tab` to move across fields.
3. Status/type fields use dropdown menus. The course field suggests existing courses as you type.
4. Due dates are edited as `MM/DD/YYYY-HH:MM` (24h). Invalid input will show an error state until corrected.

## Quick Actions
- **Mark complete**: Click the status cell and choose `Completed`. Completed rows automatically dim.
- **Delete**: With a row selected (but not editing), press `Delete`. Undo is available via `Cmd+Z`.
- **New assignment**: Press `Cmd+N` to focus the quick-add row.

## Tips
- Keep field values concise to reduce horizontal scrolling.
- Use consistent course codes so they surface in the course suggestion dropdown.
- The app automatically syncs with Supabase when online; if offline, edits stay local until connectivity returns.
