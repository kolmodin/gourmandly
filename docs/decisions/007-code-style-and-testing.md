# 007 — Code style, architecture and testing

Status: accepted (2026-10-31)

## Context

The author prefers a functional, declarative style with sealed classes and
pure functions, and wants very high unit test coverage. The backend is
Firebase ([001](001-backend.md)), so integration tests need a strategy that
doesn't depend on real cloud services.

## Decision

### Style

- **Functional core, imperative shell.** `packages/domain` holds pure
  functions over immutable data: fractions, units, scaling, merging, staples,
  checking and clearing, export, search. It depends on neither Flutter nor
  Firebase. Side effects live only at the edges: the repository layer that
  talks to Firestore, and the UI.
- **Algebraic data types** are `sealed class` hierarchies with `final`
  subclasses, consumed with exhaustive `switch` expressions and patterns.
  Records are used for small value tuples.
- **Immutable data:** `final` fields, `const` constructors where possible,
  hand-written `copyWith`. Collections are `IList`/`IMap` from
  `fast_immutable_collections`. Value equality is hand-written or via
  `equatable`. No code generation, so the tolerant reading and field-level
  writes required by [003](003-data-evolution.md) stay visible and testable.
- **Expected failures are values,** a sealed `Result` type (e.g. a page with
  no recipe, an unparseable quantity), not exceptions. Exceptions are for
  bugs and broken infrastructure.
- **Server code** (TypeScript) follows the same split: parsing and
  prompt-building are pure functions; fetching, AI calls and Firestore writes
  are the shell.

### App architecture

- **Riverpod** for state: Firestore streams in, derived values (the shopping
  list views, search results) as providers that call domain functions.
- **go_router** for navigation and the web app's URLs.
- **Dart pub workspace:** a root `pubspec.yaml` lists `app` and
  `packages/domain`, which share one dependency resolution.

### Unit tests

- `packages/domain` targets near-complete coverage; `nix run .#test` fails
  below 95% line coverage. Tests run with `flutter test --coverage`, not `dart
  test`, because pub resolves the whole workspace including the Flutter app.
- **Property-based tests** with `glados` where they add something over
  example-based tests: laws that must hold for all inputs, such as scaling by
  *a* then *b* equals scaling by *a·b*, merging is order-independent, unit
  conversion round-trips are lossless, and the export never contains a
  checked line. Plain example tests cover specific cases and readable
  documentation of behaviour.
- **Generators are checked, not assumed.** A law only proves something if the
  generated inputs reach the interesting cases, so the kitchen generator uses
  small vocabularies to force collisions, and its output was measured: merged
  lines, ties, and checks that match real lines.
- **Decisions are effects as data.** Functions such as `clearChecked` and
  `startCooking` return a list of effects (`DeleteCheck`, `UpdatePlanned`, …)
  instead of writing. The repository layer applies them (see Writing in
  [data-model.md](../data-model.md)); tests apply them to a state with
  `applyEffects`, which allows laws like "undo restores the state". A
  differential integration test requires Firestore and `applyEffects` to agree
  after every step, including that an effect on something missing does nothing.
- App: widget tests for what people do on the screens, with fake repositories
  that apply effects with `applyEffects`. Coverage there isn't gated.
- Functions: unit tests for the pure parts, using saved recipe pages.

### Integration tests

All integration tests run against the Firebase **Emulator Suite**, never real
projects. Each test resets the emulators (their REST reset endpoints) and seeds
exactly the data it needs.

| Layer | What it proves | How |
|---|---|---|
| Security Rules | Members can read and write their kitchen; outsiders, other kitchens and signed-out users can't; membership fields can't be edited by clients | `@firebase/rules-unit-testing` against the Firestore emulator |
| Functions | Import end to end; membership changes | Functions emulator, a local server with saved recipe pages, the AI behind a fake with recorded responses |
| App data layer | Repositories use Firestore correctly: field-level updates, array operations, the "old client" test from [003](003-data-evolution.md) | `integration_test` in Chrome against the emulators (see below) |
| End to end | User flows in the real app in a browser | Flutter `integration_test` via `flutter drive` in Chrome, signed in as fake users through the Auth emulator |

Multi-user and offline scenarios: the app under test is one user; the test
code acts as the other user by writing to the emulator directly; the app is
taken offline with Firestore's `disableNetwork()`.

Real AI is exercised only by a few tests run on demand, outside CI.

## Verified (2026-10-31)

- **The Firebase plugins don't work under `flutter test --platform chrome`:**
  `Firebase.initializeApp` never completes in the test harness page, because
  the plugin loads the Firebase JavaScript SDK into the page. Data-layer tests
  therefore run as `integration_test` under `flutter drive`, in the real app
  page, where the plugins work.
- **Chrome and chromedriver come from Nix** with matching versions: Google
  Chrome on macOS, Chromium on Linux (see [004](004-nix.md)). Integration tests
  run with `flutter drive -d web-server --browser-name=chrome
  --chrome-binary=$CHROME_EXECUTABLE`.
- **Screenshots** are taken from an integration test that walks through the
  seeded app (`nix run .#screenshots`), and saved by the test driver to
  `app/build/screenshots/`. That is how the design is reviewed. Chrome windows
  don't get narrower than 500 pixels, so the phone size is an app constrained
  to 412 pixels. Headless Chrome's own `--screenshot` captures a blank
  page before Flutter has rendered.
