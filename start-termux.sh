#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_PATH="$PROJECT_DIR/config.termux.yaml"

cd "$PROJECT_DIR"

if [ ! -f "$CONFIG_PATH" ] || [ ! -d node_modules ]; then
    printf 'SillyTavern is not installed for Termux yet. Run: bash %q\n' "$PROJECT_DIR/install-termux.sh" >&2
    exit 1
fi

export NODE_ENV=production

# Hold Android's wake lock only while the server is running.
WAKE_LOCK_ACQUIRED=false
if command -v termux-wake-lock >/dev/null 2>&1; then
    if termux-wake-lock; then
        WAKE_LOCK_ACQUIRED=true
    fi
fi

release_wake_lock() {
    if [ "$WAKE_LOCK_ACQUIRED" = true ] && command -v termux-wake-unlock >/dev/null 2>&1; then
        termux-wake-unlock
    fi
}
trap release_wake_lock EXIT

printf 'Starting SillyTavern with native Android settings...\n'
bash "$PROJECT_DIR/start.sh" --configPath "$CONFIG_PATH" "$@"
