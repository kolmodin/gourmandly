# Gourmandly

Recipes and shopping lists for the whole kitchen. Import a recipe from a link,
scale it, and turn a week of cooking into one shared shopping list.

The product brief is in [docs/brief.md](docs/brief.md), the data model in
[docs/data-model.md](docs/data-model.md), the look of the app in
[docs/design.md](docs/design.md), and decisions in
[docs/decisions/](docs/decisions/).

## Development

All tools come from Nix ([decision 004](docs/decisions/004-nix.md)). Enter the
development shell with `nix develop`, or let direnv load it.

| Command | What it does |
|---|---|
| `nix run` | Firebase emulators, plus the web app with hot reload at <http://localhost:8000>. Emulator UI at <http://127.0.0.1:4000>. |
| `nix run .#emulators` | The Firebase emulators only. |
| `nix run .#test` | All test suites, including integration tests in Chrome. |
| `nix run .#screenshots` | Screenshots of the seeded app at phone and tablet sizes, in `app/build/screenshots/`. |

Everything runs against the Firebase Emulator Suite with the `demo-gourmandly`
project, so no Firebase account is needed. `nix run` fills it with a kitchen of
seed recipes; use "Sign in as Anna (local)" to get in.

## Layout

```
app/              Flutter app (web for now)
packages/domain/  pure Dart domain logic
functions/        Cloud Functions (TypeScript)
firebase/         Security Rules, indexes, bucket CORS, local emulator data
scripts/          scripts behind the nix run targets
docs/             brief, data model, decisions
```

## License

[Apache-2.0](LICENSE)
