# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Git workflow
- ONE COMMIT PER FUNCTION. Not per file, not per feature area, not per
  task — per function. If a task involves writing 5 functions, that's
  5 commits minimum.
- Commit after EVERY function or component is complete and working —
  never batch multiple functions/components into one commit, never wait
  until the end of a task to commit.
- Commit message format: feat(scope): what this function/component does
- NEVER use "Step 1", "Step 2", "Part 1" etc in commit messages — each
  commit message must describe the actual code change, not the process
  used to get there.
- NEVER use `git add .` — stage only the specific files just touched
  (e.g. `git add ChargePath/ViewModels/MapViewModel.swift`).
- Push immediately after each commit — do not let commits accumulate
  locally.
- Before starting the next function/component, the previous one must
  already be committed and pushed.

## Project

ChargePath is a programmatic-UIKit iOS app (no storyboards, no SwiftUI)
for finding EV charging stations, planning routes, and running a
wallet-billed charging session. Data comes from the ChargeHub API, with
a bundled JSON seed used when no API key is configured.

- Build: `xcodebuild -project ChargePath.xcodeproj -scheme ChargePath -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Test: swap `build` for `test` in the command above (38 tests).

## Architecture

MVVM + Coordinators, constructor injection throughout.

- `Models/` — plain value types, no framework imports beyond Foundation/CoreLocation.
- `Services/` — one responsibility each (HTTP, geocoding, directions,
  location, key-value storage, payment auth). Everything is behind a
  protocol so tests can substitute doubles.
- `Repositories/` — sit between services and view models; own caching
  and the seed-vs-network decision.
- `ViewModels/` — no UIKit imports; expose state and intent methods.
- `ViewControllers/` — build their views in code; bind to one view model.
- `Coordinators/` — own navigation and view-controller construction.
- `App/DependencyContainer.swift` — the single composition root.

## DI rules

- No singletons. Nothing reaches for `.shared`.
- View models receive repositories/services via the initializer, never
  construct them.
- `DependencyContainer` is the only place that news up concrete types.

## ChargeHub key

`CHARGEHUB_API_KEY` is read from the build settings via
`Config/Base.xcconfig`, which `#include?`s the git-ignored
`Config/Secrets.xcconfig`. Copy `Config/Secrets.example.xcconfig` to
`Config/Secrets.xcconfig` and paste a key. With no key the app runs on
the bundled seed data.
