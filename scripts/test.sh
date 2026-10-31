# Runs every test suite: unit tests, then integration tests against the
# emulators in Chrome.
set -euo pipefail

root=$(git rev-parse --show-toplevel)

echo "== Functions"
(
  cd "$root/functions"
  [ -d node_modules ] || npm ci
  npm run typecheck
  npm run build
  npm test
)

echo "== Security Rules"
(
  cd "$root"
  firebase emulators:exec --only firestore,storage \
    "cd '$root/functions' && npm run test:rules"
)

echo "== Functions integration tests"
(
  cd "$root"
  firebase emulators:exec --only auth,firestore,functions,storage \
    "cd '$root/functions' && npm run test:integration"
)

echo "== Domain"
(cd "$root/packages/domain" && flutter test --coverage)
awk -F: -v minimum=95 '
  /^LF:/ { found += $2 }
  /^LH:/ { hit += $2 }
  END {
    coverage = 100 * hit / found
    printf "Domain line coverage: %.1f%% (minimum %d%%)\n", coverage, minimum
    exit coverage < minimum
  }
' "$root/packages/domain/coverage/lcov.info"

echo "== App unit tests"
(cd "$root/app" && flutter test)

echo "== Integration tests"
if curl -sf http://127.0.0.1:4444/status >/dev/null; then
  echo "Something is already listening on port 4444, stop it first." >&2
  exit 1
fi
chromedriver --port=4444 >/dev/null 2>&1 &
chromedriver_pid=$!
trap 'kill "$chromedriver_pid" 2>/dev/null || true' EXIT
until curl -sf http://127.0.0.1:4444/status >/dev/null; do sleep 0.2; done

cd "$root"
for target in "$root"/app/integration_test/*_test.dart; do
  firebase emulators:exec --only auth,firestore,functions,storage \
    "cd '$root/app' && flutter drive -d web-server --browser-name=chrome \
      --chrome-binary='$CHROME_EXECUTABLE' \
      --driver=test_driver/integration_test.dart --target='$target'"
done
