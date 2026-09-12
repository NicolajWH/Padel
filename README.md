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
  big tap zones, swipe right or use the compact undo button to take back a
  point, and get haptic feedback on every point and on match win. Works
  standalone (no phone nearby needed) and
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
- **Watch workout tracking** — scoring on the Watch runs a HealthKit workout
  session alongside: live heart rate on the scoreboard, active calories, and
  a workout saved to the Health app (recorded as tennis — HealthKit has no
  padel type). The session also keeps the app alive for the whole match so
  watchOS never suspends it mid-set. Requires the one-time Apple setup below;
  without it (or if the user declines Health access) scoring works unchanged.
- **Live Activity** — while a match is scored on the iPhone (including points
  relayed live from the Watch), the score lives on the lock screen and in the
  Dynamic Island.
- **Watch-face complication** — add the Padel complication to any watch face
  (circular, rectangular, corner or inline) and one tap jumps straight into the
  scoreboard: it resumes the match in progress, or starts a fresh quick match,
  ready to register points without opening the app first.
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

## TestFlight / GitHub Actions setup

The `Deploy to TestFlight` workflow runs on every push to `main` and can also
be started manually with **Actions → Deploy to TestFlight → Run workflow**. It
tests PadelKit, generates `Padel.xcodeproj`, imports the existing Apple
Distribution certificate into a temporary keychain, asks Apple for fresh App
Store provisioning profiles with `fastlane sigh`, builds the Release archive,
and uploads it to TestFlight. The API key, certificate file, profiles, and
keychain exist only on the ephemeral runner.

Build numbers use `GITHUB_RUN_NUMBER`, so TestFlight uploads do not collide.
The archive uses manual signing and the `app-store` export method; no Apple ID,
external signing repository, or committed credential is involved.

### Required GitHub Secrets

Create exactly these repository secrets under **Settings → Secrets and
variables → Actions**:

| Secret name | Value | Where to find it | Scope |
|---|---|---|---|
| `APP_STORE_CONNECT_KEY_ID` | The 10-character ID of the API key | App Store Connect → Users and Access → Integrations → Team Keys; also appears in `AuthKey_<KEY_ID>.p8` | Shared if the same team API key is used for multiple apps |
| `APP_STORE_CONNECT_ISSUER_ID` | The team's issuer UUID | App Store Connect → Users and Access → Integrations | Shared across the App Store Connect team |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64 of the complete downloaded `.p8` file | Download the Team API key once when creating it, then encode it as shown below | Shared if the same API key is used for multiple apps; treat as a private credential |
| `APPLE_TEAM_ID` | The 10-character Developer Program Team ID | Apple Developer → Membership details | Shared across apps belonging to the same developer team |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 of an exported `.p12` containing the Apple Distribution certificate **and private key** | Export the existing Apple Distribution identity from Keychain Access, then encode it as shown below | Shared across apps signed by that team while the certificate remains valid |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password selected when exporting the `.p12` | The password entered in Keychain Access during export | Shared only with repositories that use that `.p12` |

The API key must be a **Team Key with the Admin role**, because CI manages
Identifiers/provisioning profiles as well as uploading builds. Never commit the
`.p8`, `.p12`, their decoded contents, or their passwords.

On macOS, copy each file as a single-line base64 value suitable for a GitHub
Secret:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
base64 -i AppleDistribution.p12 | tr -d '\n' | pbcopy
```

To verify a copied value locally without writing decoded credentials into the
repository:

```bash
pbpaste | base64 --decode > /tmp/decoded-credential
```

### Provisioning profiles and signing

Provisioning profiles are intentionally **not** GitHub Secrets. On every run,
Fastlane `sigh` authenticates with the App Store Connect API key, creates or
refreshes an App Store profile for every bundle identifier, and installs it on
the runner. Each profile includes the valid distribution certificates so it
matches the imported `.p12`. This keeps expiring profiles out of both GitHub
Secrets and the repository while reusing the existing certificate/private key.

The temporary keychain gets a random per-run password. The `.p12` is deleted
immediately after import, and the API key and keychain are removed in an
`always()` cleanup step, including after failed builds.

### Required Apple-side setup

Before deploying, verify all of the following:

1. The App Store Connect app record exists for `com.worsa.padel`.
2. These explicit App IDs exist in Certificates, Identifiers & Profiles:
   `com.worsa.padel`, `com.worsa.padel.watchapp`,
   `com.worsa.padel.widgets`, and `com.worsa.padel.watchapp.widgets`.
3. HealthKit is enabled for the iPhone and Watch App IDs. The iPhone App ID
   also has iCloud/CloudKit enabled and access to `iCloud.com.worsa.padel`.
4. The Apple Distribution certificate represented by the `.p12` is valid in
   the Developer portal, and the `.p12` contains its private key.
5. The Team API key is active and has Admin access. Apple only allows its `.p8`
   to be downloaded once.

No provisioning profile needs to be created by hand. If capabilities change,
the next workflow run refreshes the profiles automatically.

## Local development (optional)

The app can be run locally in Xcode 26+ on a Mac:

```bash
brew install xcodegen
xcodegen generate
open Padel.xcodeproj
```

Select your development team in Xcode for device builds. CI never stores a
team in the public project; it supplies `DEVELOPMENT_TEAM` from the
`APPLE_TEAM_ID` secret. Simulator builds do not require signing.

The scoring-engine unit tests run anywhere Swift does:

```bash
cd Packages/PadelKit
swift test
```

## Reusing the repository for another app

The app identity is centralized in `Config/App.xcconfig`. Change its display
name, four bundle identifiers, and iCloud container, then review the
app-specific capabilities and generated entitlements in `project.yml`. Create
the corresponding Apple Identifiers/App Store Connect record and configure the
six GitHub Secrets above. The Fastlane lane reads the same xcconfig, so bundle
identifiers do not need to be duplicated in Ruby or edited throughout the
generated `project.pbxproj`.

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
- A live score *on* the watch-face complication itself (it's a launcher into
  the scoreboard — showing the running score on the face would need an App
  Group to share state across processes)
