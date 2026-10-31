# Local development: the Firebase emulators in the background, the Functions
# compiler in watch mode, and the web app in the foreground with hot reload.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
log="$root/firebase/emulators.log"

(cd "$root/functions" && { [ -d node_modules ] || npm ci; } && npm run build)
(cd "$root/functions" && exec npx tsc --watch --preserveWatchOutput >/dev/null) &
tsc_pid=$!

(
  cd "$root"
  import=()
  [ -d firebase/.emulator-data ] && import=(--import firebase/.emulator-data)
  exec firebase emulators:start "${import[@]}" --export-on-exit firebase/.emulator-data
) >"$log" 2>&1 &
emulators_pid=$!

interrupted=false
trap 'interrupted=true' INT

cleanup() {
  kill "$tsc_pid" 2>/dev/null || true
  # SIGINT lets the emulators export their data before exiting. Ctrl-C has
  # already sent them one, and a second would cut the export short.
  if [ "$interrupted" = false ]; then
    kill -INT "$emulators_pid" 2>/dev/null || true
  fi
  wait "$emulators_pid" 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting emulators (log: firebase/emulators.log)..."
until curl -sf http://127.0.0.1:4400/emulators >/dev/null; do
  kill -0 "$emulators_pid" 2>/dev/null || { cat "$log"; exit 1; }
  sleep 1
done
echo "Emulator UI: http://127.0.0.1:4000"
echo "Web app:     http://localhost:8000"

cd "$root/app"
flutter run -d web-server --web-port 8000 --dart-define=GOURMANDLY_ENV=local
