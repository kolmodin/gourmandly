# 001 — Backend: Firebase

Status: accepted (2026-10-30)

## Context

The app needs Google sign-in, shared per-kitchen data with live sync,
offline use while shopping, server-side fetching of recipe pages (browsers
block cross-origin fetches), AI for recipe extraction, a public page for shared
recipes, and hosting for the web app. The author hosts everything. The app must
be testable end-to-end.

## Options considered

- **Firebase** (Auth, Firestore, Cloud Functions, Storage, Hosting). Offline
  cache and live sync built into the Flutter Firestore client. The Emulator
  Suite runs the backend locally for development and CI. Nothing to operate.
  Downsides: vendor lock-in, Firestore's query limitations, TypeScript for
  server code, and the stored data format is the API seen by old app versions.
- **Own Dart server** (e.g. `shelf` on Cloud Run with SQLite or Postgres). One
  language with shared code between app and server, the most testable option,
  an API layer to absorb version differences. Costs a few weeks for a sync
  engine, plus ongoing ops.
- **Supabase** (+ PowerSync for offline). Postgres and a good local stack, but
  the most moving parts: two vendors, three languages.
- **PocketBase**. Simplest to run, but no offline support, so we'd still build
  sync, on a framework not designed for it.

## Decision

Use Firebase for the whole backend. Fastest path to a working app for the
family, with no servers to operate.

| Need | Firebase product |
|---|---|
| Sign-in with Google | Authentication |
| Kitchens, recipes, shopping list, offline + live sync | Cloud Firestore |
| Recipe import (page fetch, JSON-LD parsing, AI fallback, keys, tags, translation, photo), membership changes (invites, leaving, ownership, account deletion), keys for manual list items, the budget kill switch, share pages | Cloud Functions (TypeScript) |
| AI extraction, picking a photo, generating one on request | Gemini / Imagen through Genkit in Cloud Functions |
| Recipe photos, copied at import | Cloud Storage |
| Web app, `/r/{shareId}` share pages, `/.well-known/` | Hosting, custom domain `gourmandly.kolmodin.com` |
| Protecting Functions and AI spend from abuse | Auth, kitchen membership and a per-kitchen quota (see Cost and abuse); App Check on web (reCAPTCHA) once the real projects exist, on Android once the app is on Play (see [005](005-distribution.md)) |
| Crash reports (Android app, later) | Crashlytics |
| Push notifications, when needed (e.g. "an item was added to the list") | Cloud Messaging (FCM) |

AI calls run on the server, not through the client-side Firebase AI Logic SDK,
because the recipe page has to be fetched server-side anyway and the prompt and
API usage stay under our control. The AI provider sits behind an interface so it
can be swapped, and recorded responses are used in tests.

Not used: Analytics and Performance Monitoring (no need, and the project doesn't
track its users), Dynamic Links (shut down). Remote Config only if a real need
for feature flags appears.

## Environments

- **local**: Emulator Suite (Auth, Firestore, Functions, Storage, Hosting) for
  development, tests and CI.
- **dev**: Firebase project `gourmandly-dev`, `dev.gourmandly.kolmodin.com`.
- **prod**: Firebase project `gourmandly-prod`, `gourmandly.kolmodin.com`.

Functions run in `europe-north1` (Stockholm), and Firestore and Storage should
be created in the same region. `firebase.json` is at the repository root,
because firebase-tools refuses to deploy anything outside of the directory it
is in; the emulators don't check this. The Storage bucket needs the CORS setting
in `firebase/storage-cors.json` for the web app to load photos.

The web app selects its environment at build time (`--dart-define`). The
Android app, when built, gets `dev` and `prod` flavors with separate
application IDs, so both can be installed on one phone. Both projects are on
the Blaze plan with budget alerts.

## Release flow

Run by GitHub Actions once the code is on GitHub, in the Nix shells from
[004](004-nix.md):

- **Pull request:** unit tests, rules tests and integration tests against the
  emulators; the web app is deployed to a Hosting preview channel.
- **Push to `main`:** rules, indexes, Functions and the web app are deployed to
  dev.
- **Tag `vX.Y.Z`:** the same, to prod.

The Android app adds APK builds to this flow, see
[005](005-distribution.md).

## Cost and abuse

The web app is public, so anyone with a Google account can sign in and import
recipes. Left open for now; cost is kept in check by:

- a budget with alerts on each Firebase project (alerts don't stop spending);
- a per-kitchen daily import quota in the import Function, and a limit of 10
  kitchens per user, as a quota per kitchen alone could be avoided by creating
  more kitchens;
- a `meta/app.importsEnabled` kill switch, which the budget alert can flip
  automatically via Pub/Sub;
- per-kitchen daily usage records (`kitchens/{k}/usage/{yyyy-mm-dd}`: imports,
  AI tokens) and a structured log line per import (uid, kitchen, URL, method,
  tokens), so unexpected kitchens or volumes are easy to spot. The bill
  itself only breaks costs down per service and SKU, not per user.

An allowlist of Google accounts for creating kitchens can be added if abuse
shows up.

## Consequences

- No sync engine to build; conflicts resolve as last write wins per field. The
  data model keeps conflicts rare: one document per user action, derived views
  computed on the device.
- Firestore documents are the API. Changes to the data format must stay
  readable and writable by older app versions still running (see
  [003](003-data-evolution.md)).
- Kitchen access is enforced by Firestore Security Rules, which get their own
  test suite against the emulator.
- Server code is TypeScript, so logic needed on both sides (e.g. ingredient
  parsing) is either kept on one side or duplicated deliberately.
- The repo doesn't depend on the author's Firebase projects: anyone can run
  `flutterfire configure` against their own, and the domain is build-time
  configuration.
