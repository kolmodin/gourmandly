# 005 — Distribution: GitHub Releases

Status: accepted (2026-10-30). Applies once the Android app is built; v1 is
web only, deployed to Firebase Hosting.

## Context

The app is for one family, is open source, and has no monetization. Google
Play adds a developer account, store listing, review and policy work that
buys little at this scale.

## Decision

GitHub Actions builds the app and publishes it on GitHub. Google Play is on
the wishlist. This extends the release flow in [001](001-backend.md):

- **Release** (tag `vX.Y.Z` on `main`): also build a signed prod APK and
  attach it to a GitHub Release.
- **Dev builds** (every push to `main`): also build a signed dev-flavor APK
  (separate application ID, dev backend) as a pre-release.
- **Builds run in the Nix shell** (`nix develop -c …`), the same tools as
  locally (see [004](004-nix.md)).
- **Universal APK**, not App Bundle: App Bundles are for Play.
- **versionCode** is derived from the version tag so every release is
  installable as an update.

### Signing

- One release keystore, used for both flavors. It is stored as GitHub Actions
  secrets (base64 keystore, passwords) and backed up outside GitHub. Losing it
  means every phone has to uninstall and reinstall to get updates.
- The keystore's SHA-1 and SHA-256 fingerprints are registered in both Firebase
  projects; Google sign-in on Android depends on them.

### Installing and updating

- First install: download the APK from the Releases page on the phone and allow
  the browser to install unknown apps.
- Updates: [Obtainium](https://github.com/ImranR98/Obtainium) watches the
  GitHub Releases and installs new versions. In addition, the app compares its
  version with the latest release and links to it when it's outdated.
- Wishlist: built-in auto-update, where the app downloads the new APK from
  GitHub Releases itself, checks its checksum, and installs it with Android's
  package installer. Replaces Obtainium once it exists.
- `meta/app.minSupportedVersion` (see [003](003-data-evolution.md)) matters
  more than with Play, since nothing updates the app automatically.

## Keeping the path to Google Play open

Moving to Play later works without reinstalling, if:

- **The package name never changes:** `com.kolmodin.gourmandly`, and
  `com.kolmodin.gourmandly.dev` for the dev flavor.
- **The signing key is kept** and uploaded to Play App Signing ("use my own
  key") when enrolling, instead of letting Google generate one. Play-built
  updates then carry the same signature, so installed copies update from Play.
  With a Google-generated key, every phone would have to uninstall first.
  The keystore is created with a long validity (Play requires it to be valid
  until at least 2033).
- **versionCode keeps increasing** across both channels.
- **Self-updating is a build-time option** that's off in Play builds: Play
  doesn't allow apps to install updates of themselves, and restricts the
  install-packages permission.
- **Account deletion** exists in the app and on the web, and a privacy policy
  is published on the domain; Play requires both for apps with sign-in.

New personal Play developer accounts must run a closed test (12 testers, 14
days) before publishing to production. The internal testing track (up to 100
testers, no review) can serve the family indefinitely instead.

If GitHub Releases are kept alongside Play, those installs fail Play Integrity,
so App Check can't be enforced on Android while both channels exist.

## Consequences

- **App Check:** the Play Integrity provider rejects apps not installed from
  Play, so App Check isn't used on Android for now. The import Function
  instead requires a signed-in user who belongs to a kitchen, and enforces
  a per-kitchen daily quota. App Check returns together with Play.
- **Who can use it:** the APK is public, like the web app; the cost and abuse
  measures in [001](001-backend.md) cover both.
- **Android developer verification:** Google is rolling out a requirement that
  apps installed on certified Android devices come from a verified developer,
  including apps installed outside Play (first countries from 2026-09-30,
  globally in 2027). Unverified apps can still be installed through an
  "advanced flow" (a one-time restart and 24-hour wait) or through ADB.
  Before it reaches Sweden, register as a developer and register the package
  name and signing key, so installs and updates stay smooth.
