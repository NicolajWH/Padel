# Padel

A native iOS + Apple Watch app for scoring padel matches, with a built-in
Americano tournament mode. Score a whole match from your wrist, run an
Americano evening with automatic partner rotation, and ship builds straight
to TestFlight via GitHub Actions.

## Features

- **Real padel scoring** — points (0/15/30/40), deuce & advantage or "golden point" sudden death, games, sets, tiebreaks and configurable match formats.
- **Apple Watch scoring** — score a full match on the Watch with undo, haptics and WatchConnectivity sync.
- **Americano and Mexicano** — tournament scheduling, live standings and Watch support.
- **Match history & player stats** — saved matches, win rates, ratings and head-to-head statistics.
- **Shareable standings** — export tournament standings as an image.
- **Watch workout tracking** — HealthKit workout session with heart rate and active calories.
- **Live Activity** — score on the iPhone lock screen and Dynamic Island.
- **Watch-face complication** — one-tap access to the scoreboard.

## Architecture

```
Padel/
├── Packages/PadelKit/        Swift package: scoring/tournament logic
├── iOS/PadelApp/             SwiftUI iOS app
├── WatchApp/PadelWatch/      SwiftUI watchOS app
├── project.yml               XcodeGen specification
├── fastlane/                 TestFlight deployment
└── .github/workflows/        CI + TestFlight deployment
```

The project has no physical `.xcodeproj` committed. GitHub Actions generates it from `project.yml` with XcodeGen on every build.

# TestFlight setup from Windows

This repository is designed so that the initial TestFlight setup can be done from **Windows and a web browser**. You do not need a local Mac to create or export an Apple Distribution `.p12` certificate.

GitHub Actions runs the build on a macOS runner. Xcode uses Apple's automatic/cloud-managed signing and authenticates with an App Store Connect API key.

You need exactly **three GitHub repository secrets**:

1. `APP_STORE_CONNECT_KEY_ID`
2. `APP_STORE_CONNECT_ISSUER_ID`
3. `APP_STORE_CONNECT_API_KEY_BASE64`

The Apple Developer Team ID is not a secret. It is stored in `project.yml` as `DEVELOPMENT_TEAM`.

## Step 1 — Create an App Store Connect API key

Open App Store Connect in your browser:

https://appstoreconnect.apple.com/access/integrations/api

Go to **Users and Access → Integrations → App Store Connect API → Team Keys**.

Create a Team API key with sufficient access for the CI deployment. Download the `.p8` private-key file when Apple offers it and keep it somewhere safe. Apple only allows the private key to be downloaded once.

The downloaded filename normally contains the Key ID, for example:

```
AuthKey_2X9R4HXF34.p8
```

Do not commit this file to the repository.

## Step 2 — Add `APP_STORE_CONNECT_KEY_ID`

On the Team Keys page, find **Key ID** for the key you just created.

It looks similar to:

```
2X9R4HXF34
```

Check before continuing:

- It is the **Key ID**, not the Team ID.
- It is normally 10 characters.
- It also appears in the downloaded filename `AuthKey_<KEY_ID>.p8`.

Open this repository on GitHub and go to:

**Settings → Secrets and variables → Actions → New repository secret**

Create:

```
Name:   APP_STORE_CONNECT_KEY_ID
Secret: <your Key ID>
```

Click **Add secret**.

## Step 3 — Add `APP_STORE_CONNECT_ISSUER_ID`

Return to **App Store Connect → Users and Access → Integrations** and copy the **Issuer ID**.

It is a UUID and looks similar to:

```
57246542-96fe-1a63-e053-0824d011072a
```

Check before continuing:

- It contains four hyphens.
- It is 36 characters including the hyphens.
- It is labelled **Issuer ID** in App Store Connect.

In GitHub, return to:

**Settings → Secrets and variables → Actions → New repository secret**

Create:

```
Name:   APP_STORE_CONNECT_ISSUER_ID
Secret: <your Issuer ID>
```

Click **Add secret**.

## Step 4 — Add the private API key

The third secret contains the private key from the `.p8` file downloaded in Step 1.

If you open the `.p8` file in a text editor, the original file looks approximately like this:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdw...
-----END PRIVATE KEY-----
```

Both the `BEGIN PRIVATE KEY` and `END PRIVATE KEY` lines are part of the key. Do not delete them.

The GitHub secret used by this repository stores a Base64 representation of the **complete file**. This makes the multiline file safe to recreate exactly on the GitHub macOS runner.

Do **not** upload the `.p8` file to an online Base64 converter. It is a private signing credential.

On Windows, use a trusted local/offline method to Base64-encode the complete `.p8` file. The resulting value will be one long text value and will no longer visibly start with `-----BEGIN PRIVATE KEY-----`.

Then create this GitHub repository secret:

```
Name:   APP_STORE_CONNECT_API_KEY_BASE64
Secret: <the complete Base64 value>
```

Click **Add secret**.

## Step 5 — Check the three secrets

Under **Settings → Secrets and variables → Actions → Repository secrets**, you should now see exactly these deployment secrets:

```
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_API_KEY_BASE64
```

You do **not** need these old secrets:

```
APPLE_TEAM_ID
IOS_DISTRIBUTION_CERTIFICATE_BASE64
IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
```

If they exist from an earlier setup, they are no longer referenced by the TestFlight workflow and can be removed after the new deployment has been verified.

## Step 6 — Apple-side identifiers and capabilities

The following explicit App IDs must exist in Apple Developer:

```
com.worsa.padel
com.worsa.padel.watchapp
com.worsa.padel.widgets
com.worsa.padel.watchapp.widgets
```

HealthKit must be enabled for the iPhone and Watch App IDs. The iPhone App ID also uses iCloud/CloudKit with `iCloud.com.worsa.padel`.

The App Store Connect app record must exist for `com.worsa.padel`.

Provisioning profiles do not need to be stored in GitHub. The build uses Xcode automatic signing and `-allowProvisioningUpdates` on the GitHub-hosted macOS runner.

## Step 7 — Deploy to TestFlight

Open the repository on GitHub and select:

**Actions → Deploy to TestFlight → Run workflow**

The workflow will:

1. Run the PadelKit unit tests.
2. Generate the Xcode project.
3. Check that all three required secrets exist.
4. Recreate the `.p8` API key temporarily on the runner.
5. Let Xcode manage signing/provisioning with Apple.
6. Build the Release archive.
7. Upload the build to TestFlight.
8. Delete the temporary API-key file.

The workflow also runs automatically on pushes to `main`.

## Signing model

There is deliberately no exported `.p12`, certificate password, Fastlane Match repository, or manually stored provisioning profile in this setup.

`DEVELOPMENT_TEAM` is stored in `project.yml`. The App Store Connect API key is supplied by GitHub Secrets. During the build, Xcode receives the API-key path, Key ID and Issuer ID together with `-allowProvisioningUpdates` and uses automatic signing.

Build numbers use `GITHUB_RUN_NUMBER` so TestFlight uploads do not collide.

## Local development (optional)

Local Xcode development still requires a Mac, but it is not required for the GitHub/TestFlight setup described above.

On a Mac:

```bash
brew install xcodegen
xcodegen generate
open Padel.xcodeproj
```

The scoring-engine unit tests run anywhere Swift is available:

```bash
cd Packages/PadelKit
swift test
```

## Reusing the repository for another app

The app identity is centralized in `Config/App.xcconfig`. Change the display name, bundle identifiers and iCloud container, then review the capabilities and entitlements in `project.yml`.

For another app on the same Apple team, the same App Store Connect Team API key can normally be reused. Create the corresponding Apple identifiers/App Store Connect record and configure the same three GitHub secret names in the new repository.
