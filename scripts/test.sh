# Runs every test suite: unit tests, then integration tests against the
# emulators in Chrome.
set -euo pipefail

root=$(git rev-parse --show-toplevel)

has_files() { compgen -G "$1" >/dev/null; }

echo "== Functions"
(cd "$root/functions" && { [ -d node_modules ] || npm ci; } && npm run build)
if has_files "$root/functions/src/**/*.test.ts" || has_files "$root/functions/src/*.test.ts"; then
  (cd "$root/functions" && npm test)
fi

echo "== Domain"
if has_files "$root/packages/domain/test/*_test.dart"; then
  (cd "$root/packages/domain" && flutter test)
fi

echo "== App unit tests"
if has_files "$root/app/test/*_test.dart"; then
  (cd "$root/app" && flutter test)
fi

echo "== Integration tests"
chromedriver --port=4444 >/dev/null 2>&1 &
chromedriver_pid=$!
trap 'kill "$chromedriver_pid" 2>/dev/null || true' EXIT

cd "$root/firebase"
for target in "$root"/app/integration_test/*_test.dart; do
  firebase emulators:exec --only auth,firestore,functions,storage \
    "cd '$root/app' && flutter drive -d web-server --browser-name=chrome \
      --chrome-binary='$CHROME_EXECUTABLE' \
      --driver=test_driver/integration_test.dart --target='$target'"
done
