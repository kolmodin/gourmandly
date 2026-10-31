# Starts the Firebase emulators on the demo project, keeping local data
# between runs in firebase/.emulator-data.
set -euo pipefail

root=$(git rev-parse --show-toplevel)

(cd "$root/functions" && { [ -d node_modules ] || npm ci; } && npm run build)

cd "$root/firebase"
import=()
[ -d .emulator-data ] && import=(--import .emulator-data)
exec firebase emulators:start "${import[@]}" --export-on-exit .emulator-data
