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
  points accumulate across rounds. Fully playable from the Watch. When the
  player count doesn't fill the courts, sit-outs rotate fairly and the app
  shows who's resting each round.
- **Mexicano mode** — the other tournament format the padel world plays:
  every round is re-drawn from the live standings (1st + 4th vs 2nd + 3rd in
  each group of four) so games get more even as the evening progresses.
  Rounds appear one at a time as courts finish. Works on iPhone and Watch,
  and both devices derive the next round deterministically so they can never
  disagree about the draw.
- **Match history & player stats** — every match and Americano session is
  saved; the Players tab shows each saved player's win rate and an Elo-style
  rating, and tapping a player opens head-to-head records and per-partner
  chemistry computed across matches *and* Americano rounds.
- **Shareable standings** — export the live or final Americano/Mexicano
  leaderboard as an image straight into the group chat.
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

The project has **no physical `.xcodeproj` committed** — CI generates it from
`project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) on every
build.

## Deploying to TestFlight

**This project is deployed straight from GitHub Actions — no local Xcode or
Mac is needed.** `.github/workflows/testflight.yml` runs the PadelKit unit
tests, generates the Xcode project, builds both apps with **Xcode 26**
(App Store Connect requires the iOS 26 SDK), signs them via cloud signing,
and uploads to TestFlight:

- automatically on every **push to `main`**
- or on demand via **Actions → Deploy to TestFlight → Run workflow**

Every build gets a unique build number from the GitHub Actions run number,
so uploads never collide. After a green run, Apple processes the build for
5–15 minutes before it appears under the app's TestFlight tab in App Store
Connect.

### Configuration (already set up — reference for changes)

**GitHub Actions secrets** (Settings → Secrets and variables → Actions).
Exactly these five; no Apple ID email or password is needed anywhere — the
API key fully replaces interactive Apple ID login for building, signing,
and uploading:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | The 10-character Apple Developer Team ID (Developer Portal → Membership) |
| `APP_STORE_CONNECT_KEY_ID` | The API key's ID — the `XXXXXXXXXX` in `AuthKey_XXXXXXXXXX.p8` |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID shown on the Integrations page (shared by all keys) |
| `APP_STORE_CONNECT_KEY_CONTENT` | The `.p8` key — raw PEM, base64 of the file, or just its inner base64 body all work |
| `MATCH_PASSWORD` | Any passphrase you choose — encrypts the signing certificate stored on the `certificates` branch |

**The API key must be a Team Key with the Admin role** (App Store Connect →
Users and Access → Integrations → **Team Keys**). Lesser roles can create
development certificates but fail cloud signing for distribution with
"Cloud signing permission error", and Individual Keys fail authentication
outright because they don't use the team Issuer ID.

**Apple-side registrations** (already done for this app):
- App record in App Store Connect with bundle ID `com.worsa.padel`
- The Watch app's `com.worsa.padel.watchapp` identifier is registered
  automatically by cloud signing — no manual step

The Fastlane lane validates the key against the App Store Connect API before
building, so a misconfigured secret fails in under a minute with a precise
message instead of a cryptic signing error later. Signing uses `fastlane
match`: one Apple Distribution certificate and the App Store profiles for
both bundle ids are created once, encrypted with `MATCH_PASSWORD`, and stored
on this repository's `certificates` branch. Every CI run reuses that same
certificate — ephemeral runners previously minted a fresh "Created via API"
development certificate per run until the account hit Apple's certificate
cap.

## Local development (optional)

The app can also be run locally in Xcode 26+ on a Mac — this is never
required for deploying:

```bash
brew install xcodegen
xcodegen generate
open Padel.xcodeproj
```

Pick the **PadelApp** scheme to run on an iPhone (or Simulator with a paired
Watch Simulator), or the **PadelWatch** scheme to run the Watch app on its own.

The scoring-engine unit tests run anywhere Swift does, no Xcode project
needed:

```bash
cd Packages/PadelKit
swift test
```

## Changing bundle identifiers / team

Everything Apple-specific lives in three places:

- `PRODUCT_BUNDLE_IDENTIFIER` for each target in `project.yml`
- `app_identifier` in `fastlane/Appfile`
- the bundle ID probed by the key-validation step in `fastlane/Fastfile`

Update those, create a matching app record in App Store Connect, and the
same workflow works unchanged.

## Notes on the Americano scheduler

The schedule generator (`AmericanoScheduler.generateSchedule`) is a greedy
heuristic, not a full combinatorial optimiser: each round it shuffles the
player pool and, for every group of four, picks whichever of the three
possible partner splits has been used least often so far. Over several
rounds this gives a good spread of partners without needing precomputed
"social golfer problem" tables, and it degrades gracefully for odd player
counts (sit-outs rotate so whoever has rested the least rests next).

Mexicano rounds can't be scheduled up front — each draw depends on the
standings — so they're generated one at a time by
`AmericanoScheduler.nextRound(for:)` when every court in the current round
has finished. That generation is *deterministic*: it's seeded from the
session id and round index (`SeededRandomNumberGenerator`, SplitMix64),
including the new round's UUIDs, so the iPhone and the Watch independently
compute byte-identical rounds and WatchConnectivity sync converges without
any merge logic.

## What's intentionally out of scope

- iPad-specific layouts (the app is iPhone + Watch only, `TARGETED_DEVICE_FAMILY: "1"`)
- iCloud/CloudKit sync across a user's own multiple devices (Watch↔iPhone
  sync is handled directly over WatchConnectivity instead)
- watch complications
