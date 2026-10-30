# 002 — Android minSdk

Status: accepted (2026-10-30). Applies once the Android app is built; v1 is
web only.

## Context

The family's phones include a Samsung Galaxy S20, whose last Android update is
Android 13 (API 33). Raising minSdk after release cuts existing users off from
updates; lowering it is free.

minSdk only decides which platform APIs can be called without version checks.
New platform behaviour (edge-to-edge, predictive back, permission changes) is
driven by `targetSdk`, which Google Play requires to be recent regardless, and
most newer APIs this app could use are available on older versions through
Jetpack libraries (Credential Manager, photo picker, per-app language).

## Options

- **API 26 (Android 8):** wider reach, little extra code.
- **API 33 (Android 13):** covers every device in the family, smallest test
  matrix. Notification permission and the photo picker are native.
- **API 34+:** would exclude the S20 and gains nothing this app needs.

## Decision

minSdk 33. `targetSdk` and `compileSdk` follow the latest stable Android.
Revisit (lowering is free) if someone with an older device wants to use the app.
