# Developer Guide

## Prerequisites
- macOS 13+
- Xcode 15+
- Swift 5.9 toolchain
- Supabase CLI (`brew install supabase/tap/supabase`)
- Node.js 18+ (for Supabase tooling)

## Bootstrapping
```
./scripts/bootstrap.sh
```
This script installs Homebrew dependencies (if missing), copies example config files, and reminds you to supply Supabase credentials.

## Running the App
1. Open `Stack.xcodeproj` in Xcode.
2. Select the "Stack" scheme.
3. Build & run on "My Mac".

## Local Supabase
1. Export environment variables from `supabase/config/supabase.env.example` or copy to `.env`.
2. Start Supabase locally:
   ```
   supabase start
   ```
3. Apply migrations:
   ```
   supabase db reset
   ```
4. Generate Swift types if desired:
   ```
   ./scripts/generate-supabase-types.sh
   ```

## Coding Standards
- Swift code follows SwiftLint rules in `.swiftlint.yml` and shared typography/color helpers.
- Keep view logic declarative; place business rules inside view models or repositories.
- Update documentation and tests when adding features.

## Testing
```
xcodebuild -project Stack.xcodeproj -scheme Stack -destination 'platform=macOS' test
```
Unit tests live under `Tests/StackTests`. UI coverage starts in `Tests/StackUITests`.

## Commit Process
- Run the formatter (`scripts/format.sh`).
- Ensure unit tests pass.
- Keep commits scoped and reference an issue when applicable.
