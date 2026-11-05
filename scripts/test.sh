# Runs the test suites named as arguments, or all of them: static checks and
# unit tests, then integration tests against the emulators in Chrome. CI runs
# each suite in its own job, with the Nix shell it needs.
#
#   checks       flutter analyze, dart format     (shell: dart)
#   domain       domain tests, 95% line coverage  (shell: dart)
#   app          app unit tests                   (shell: dart)
#   functions    Functions typecheck, unit tests  (shell: functions)
#   rules        Security Rules tests             (shell: emulators)
#   functions-integration
#                Functions against the emulators  (shell: emulators)
#   integration  app tests in Chrome              (shell: integration)
set -euo pipefail

root=$(git rev-parse --show-toplevel)

build_functions() {
  cd "$root/functions"
  [ -d node_modules ] || npm ci
  npm run build
}

suite_checks() {
  cd "$root"
  flutter analyze
  dart format --output=none --set-exit-if-changed app packages
}

suite_domain() {
  cd "$root/packages/domain"
  flutter test --coverage
  awk -F: -v minimum=95 '
    /^LF:/ { found += $2 }
    /^LH:/ { hit += $2 }
    END {
      coverage = 100 * hit / found
      printf "Domain line coverage: %.1f%% (minimum %d%%)\n", coverage, minimum
      exit coverage < minimum
    }
  ' coverage/lcov.info
}

suite_app() {
  cd "$root/app"
  flutter test
}

suite_functions() {
  build_functions
  npm run typecheck
  npm test
}

suite_rules() {
  build_functions
  cd "$root"
  firebase emulators:exec --only firestore,storage \
    "cd '$root/functions' && npm run test:rules"
}

suite_functions_integration() {
  build_functions
  cd "$root"
  firebase emulators:exec --only auth,firestore,functions,storage \
    "cd '$root/functions' && npm run test:integration"
}

suite_integration() {
  build_functions
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
      "cd '$root/functions' && npm run seed && cd '$root/app' && \
        flutter drive -d web-server --browser-name=chrome \
        --chrome-binary='$CHROME_EXECUTABLE' \
        --driver=test_driver/integration_test.dart --target='$target'"
  done
}

all=(checks domain app functions rules functions-integration integration)
[ $# -gt 0 ] || set -- "${all[@]}"
for suite in "$@"; do
  run=suite_${suite//-/_}
  if ! declare -F "$run" >/dev/null; then
    echo "Unknown suite: $suite (one of: ${all[*]})" >&2
    exit 2
  fi
  echo "== $suite"
  ("$run")
done
