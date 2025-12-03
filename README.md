# Stack

Stack is a macOS SwiftUI app for fast, keyboard-driven assignment tracking backed by Supabase/Postgres. The project is structured as a monorepo that contains the Swift client, Supabase schema/migrations, and tooling required for local development.

## Features
- Dark-mode only UI modeled after native macOS productivity apps
- Inline editing for every assignment field with keyboard shortcuts for navigation, deletion, and quick-add
- Supabase/Postgres backend with migrations and seed data checked into the repo
- Quick-add row pinned to the top of the list for rapid entry without modal dialogs

## Repository Layout
See the inline comments in the specification or browse the directory tree for a tour of the modules:

```
Stack/
├── Stack/                # SwiftUI source
├── supabase/             # Database schema and config
├── scripts/              # Tooling for bootstrapping and formatting
├── docs/                 # Architecture and user-facing documentation
└── Tests/                # Unit and UI tests
```

## Getting Started
1. Install Xcode 15 or newer plus the Swift toolchain.
2. Install the Supabase CLI (`brew install supabase/tap/supabase`).
3. Run `scripts/bootstrap.sh` from the repo root to install dependencies and copy config templates (`Config/Environment.plist` and `supabase/config/supabase.env`). Populate those with your Supabase URL/anon key, or export `SUPABASE_URL`/`SUPABASE_ANON_KEY` in your shell instead.
4. Open `Stack.xcodeproj` in Xcode and select the "Stack" scheme to build and run.
5. Follow `docs/SUPABASE_SETUP.md` to start a local Supabase instance and run migrations.

## Contributing
Please read the docs in the `docs/` folder for architecture details, coding conventions, and development workflows. Pull requests should include updated documentation and tests where applicable.

## License
MIT License. See [LICENSE](LICENSE) for details.
