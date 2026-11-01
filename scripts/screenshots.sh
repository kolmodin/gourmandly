# Takes screenshots of the seeded app at phone and tablet sizes, for reviewing
# the design. They end up in app/build/screenshots/.
set -euo pipefail

root=$(git rev-parse --show-toplevel)

(cd "$root/functions" && { [ -d node_modules ] || npm ci; } && npm run build)

if curl -sf http://127.0.0.1:4444/status >/dev/null; then
  echo "Something is already listening on port 4444, stop it first." >&2
  exit 1
fi
chromedriver --port=4444 >/dev/null 2>&1 &
chromedriver_pid=$!
trap 'kill "$chromedriver_pid" 2>/dev/null || true' EXIT
until curl -sf http://127.0.0.1:4444/status >/dev/null; do sleep 0.2; done

cd "$root"
for size in phone:412x915 tablet:1180x820; do
  firebase emulators:exec --only auth,firestore,functions,storage \
    "cd '$root/functions' && npm run seed && cd '$root/app' && \
      flutter drive -d web-server --browser-name=chrome \
      --chrome-binary='$CHROME_EXECUTABLE' \
      --browser-dimension=${size#*:} --dart-define=SCREEN=${size%%:*} \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/screens_test.dart"
done
