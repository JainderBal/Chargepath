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
for finding EV charging stations, planning routes with charging stops,
in-app turn-by-turn navigation, and running a wallet-billed charging
session. Live station data comes from Open Charge Map (ChargeHub is kept
as a second worked example of the same `StationService` seam); a bundled
JSON seed is the offline fallback. Turn-by-turn is the Google Navigation
SDK, behind the `TurnByTurnNavigator` protocol.

- Build: `xcodebuild -project ChargePath.xcodeproj -scheme ChargePath -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Test: swap `build` for `test` in the command above (46 tests).
- The iOS Simulator sometimes fails the first launch with "Busy /
  Application failed preflight checks" — `xcrun simctl bootstatus "iPhone 17 Pro" -b`
  before the test command, then retry.

## Architecture

MVVM + Coordinators, constructor injection throughout.

- `Models/` — plain value types, no framework imports beyond Foundation/CoreLocation.
- `Services/` — one responsibility each (HTTP, station APIs, geocoding,
  directions, turn-by-turn navigation, location, key-value storage,
  payment auth). Everything is behind a protocol so tests can substitute
  doubles. Vendor SDKs (Google Navigation) stay isolated here behind
  `#if canImport(...)` and a protocol seam.
- `Repositories/` — sit between services and view models; own caching
  and the seed-vs-network decision.
- `ViewModels/` — no UIKit or vendor-SDK imports; expose state and intent
  methods.
- `ViewControllers/` — build their views in code; bind to one view model.
- `Coordinators/` — own navigation and view-controller construction.
- `App/DependencyContainer.swift` — the single composition root.
- Screens are MVVM sets: `MapViewController`/`MapViewModel`,
  `StationDetail…`, `ActivateCharging…`, `ActiveSession…`,
  `RoutePlanner…`, `Navigation…`, `Settings…`, `VehicleSelection…`,
  `Wallet…`, `Filter…`.

## DI rules

- No app-owned singletons beyond `HTTPSession.shared` (one Alamofire
  `Session`) and vendor singletons initialised once in `AppDelegate`
  (`GMSServices`). App code never reaches for `.shared` otherwise.
- View models receive repositories/services via the initializer, never
  construct them. The Navigation screen is the one allowed exception:
  `GMSMapView` and its navigator are inseparable, so the VC creates the
  map view and hands the navigator to the VM via `bind(navigator:)`.
- `DependencyContainer` is the only place that news up concrete types.

## API keys

All three are read from build settings via `Config/Base.xcconfig`, which
`#include?`s the git-ignored `Config/Secrets.xcconfig` (copy
`Config/Secrets.example.xcconfig` to start). Each also accepts a
same-named environment variable as a fallback.

- `OPEN_CHARGE_MAP_API_KEY` — live map data. Empty ⇒ keyless (rate-limited)
  then seed fallback.
- `GOOGLE_MAPS_API_KEY` — Google Navigation SDK. Needs a billing-enabled
  Google Cloud project with the Navigation + Maps SDKs enabled. Empty ⇒
  the Navigation screen shows a placeholder. `AppDelegate` calls
  `GMSServices.provideAPIKey`.
- `CHARGEHUB_API_KEY` — optional; only the ChargeHub worked-example
  service uses it.
