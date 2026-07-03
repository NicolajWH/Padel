# Padel

A native iOS + Apple Watch app for scoring padel matches, with a built-in
Americano tournament mode. Score a whole match from your wrist, run an
Americano evening with automatic partner rotation, and ship builds straight
to TestFlight via GitHub Actions.

## Features

- **Real padel scoring** — points (0/15/30/40), deuce & advantage or
  "golden point" sudden death, games, sets, tiebreaks (regular and
  10-point match tiebreak for the decider), configurable best-of-1/best-of-3.
- **Apple Watch scoring** — score a full match entirely on the Watch:
  big left/right tap zones, Digital Crown to undo, haptic feedback on every
  point and on match win. Works standalone (no phone nearby needed) and
  live-syncs to the iPhone app over WatchConnectivity when it's around.
- **Americano mode** — set up a group of players (4, 8, 12, 16…), auto-generate
  a round schedule that rotates partners/opponents to minimise repeats, score
  each court's race-to-N points, and see a live individual leaderboard as
  points accumulate across rounds. Fully playable from the Watch.
- **Match history & player stats** — every match and Americano session is
  saved; the Players tab shows each saved player's win rate.
- **Serve indicator** — shows which team *and which of the two partners* is
  serving, based on real padel serve rotation rules.
- **Player profiles** — save players once, quick-add them into new matches or
  Americano sessions, colour-coded avatars.

## Architecture

```
Padel/
├── Packages/PadelKit/        Swift package: all scoring/tournament logic
│   ├── Sources/PadelKit/     Player, Team, MatchEngine, AmericanoScheduler…
│   └── Tests/PadelKitTests/  XCTest unit tests for the scoring engine
├── iOS/PadelApp/             SwiftUI iOS app (SwiftData persistence)
├── WatchApp/PadelWatch/      SwiftUI watchOS app (standalone-capable)
├── project.yml               XcodeGen spec — generates Padel.xcodeproj
├── fastlane/                 Fastfile/Appfile for the TestFlight lane
└── .github/workflows/        CI: unit tests + TestFlight deploy
```

**PadelKit** is the single source of truth for all rules. Both apps depend on
it as a local Swift package, so the iPhone and the Watch can never disagree
about what a score means. Scoring state is stored as an *append-only log of
point winners* (`pointLog: [TeamSide]`); the visible score (games, sets,
deuce/advantage, tiebreak, winner) is always re-derived from that log by a
pure function (`MatchEngine.simulate`). That makes "undo" trivial and
correct (drop the last log entry) and makes syncing between devices safe —
whichever device has the longer log wins, no merge logic needed.

The project has **no physical `.xcodeproj` committed** — it's generated from
`project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). Run
`xcodegen generate` (or let CI do it) whenever you want an up-to-date
`Padel.xcodeproj`.

## Requirements

- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 17+ / watchOS 10+ (uses SwiftData + modern SwiftUI APIs)

## Running locally

```bash
brew install xcodegen
xcodegen generate
open Padel.xcodeproj
```

Pick the **PadelApp** scheme to run on an iPhone (or Simulator with a paired
Watch Simulator), or the **PadelWatch** scheme to run the Watch app on its own.

To run just the scoring-engine unit tests without opening Xcode:

```bash
cd Packages/PadelKit
swift test
```

## Deploying to TestFlight

`.github/workflows/testflight.yml` builds both targets and uploads to
TestFlight automatically on every push to `main`, or on demand via
**Actions → Deploy to TestFlight → Run workflow**.

### One-time setup (required before the Action can succeed)

1. **Register the app in App Store Connect / the Developer Portal** with the
   bundle identifiers from `project.yml`:
   - iOS app: `com.worsa.padel`
   - Watch app: `com.worsa.padel.watchapp`

   (Change these in `project.yml` first if you want a different identifier —
   they must be registered under your own Apple Developer team.)

2. **Create an App Store Connect API key**: App Store Connect →
   Users and Access → Integrations → App Store Connect API → generate a key
   with the *App Manager* role. Note the **Key ID**, **Issuer ID**, and
   download the `.p8` file.

3. **Add these GitHub Actions secrets** (Settings → Secrets and variables →
   Actions):

   | Secret | Value |
   |---|---|
   | `APPLE_ID` | Your Apple ID email (used by fastlane's Appfile) |
   | `APPLE_TEAM_ID` | Your 10-character Apple Developer Team ID |
   | `APP_STORE_CONNECT_TEAM_ID` | Your App Store Connect team ID (Developer Portal → Membership) |
   | `APP_STORE_CONNECT_KEY_ID` | The API key ID from step 2 |
   | `APP_STORE_CONNECT_ISSUER_ID` | The API key's issuer ID from step 2 |
   | `APP_STORE_CONNECT_KEY_CONTENT` | The `.p8` file contents, **base64-encoded**: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

The workflow uses `xcodebuild -allowProvisioningUpdates` with that API key,
so Xcode automatically creates/refreshes the signing certificate and App
Store provisioning profiles during CI — no manual certificates, no `match`
repo to maintain.

Every build gets a unique build number derived from the GitHub Actions run
number, so repeated uploads to TestFlight never collide.

## Configuring your own bundle identifiers / team

Everything Apple-specific lives in `project.yml` and `fastlane/Appfile`:

- `PRODUCT_BUNDLE_IDENTIFIER` for each target in `project.yml`
- `app_identifier` in `fastlane/Appfile`

Update those, re-register the new identifiers in the Developer Portal, and
the same workflow will work unchanged.

## Notes on the Americano scheduler

The schedule generator (`AmericanoScheduler.generateSchedule`) is a greedy
heuristic, not a full combinatorial optimiser: each round it shuffles the
player pool and, for every group of four, picks whichever of the three
possible partner splits has been used least often so far. Over several
rounds this gives a good spread of partners without needing precomputed
"social golfer problem" tables, and it degrades gracefully for odd player
counts (players are dropped one round at a time if the count isn't a
multiple of 4).

## What's intentionally out of scope

- iPad-specific layouts (the app is iPhone + Watch only, `TARGETED_DEVICE_FAMILY: "1"`)
- iCloud/CloudKit sync across a user's own multiple devices (Watch↔iPhone
  sync is handled directly over WatchConnectivity instead)
- watch complications
