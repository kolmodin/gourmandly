# Starts the Firebase emulators on the demo project, keeping local data
# between runs in firebase/.emulator-data.
set -euo pipefail

root=$(git rev-parse --show-toplevel)

(cd "$root/functions" && { [ -d node_modules ] || npm ci; } && npm run build)

cd "$root"
import=()
[ -d firebase/.emulator-data ] && import=(--import firebase/.emulator-data)
exec firebase emulators:start "${import[@]}" --export-on-exit firebase/.emulator-data
