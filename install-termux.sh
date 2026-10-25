#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_PATH="$PROJECT_DIR/config.termux.yaml"

fail() {
    printf 'Termux install error: %s\n' "$*" >&2
    exit 1
}

[ "$(uname -o 2>/dev/null)" = "Android" ] || fail "Run this installer inside Termux on Android, not in a desktop or proot distribution."
[ -n "${PREFIX:-}" ] || fail "The Termux PREFIX environment variable is missing."
command -v pkg >/dev/null 2>&1 || fail "The Termux pkg command is unavailable."

case "$PROJECT_DIR" in
    "$HOME"|"$HOME"/*|"$PREFIX"|"$PREFIX"/*) ;;
    *) fail "Move SillyTavern into the Termux home directory first. Do not install it from shared storage (/sdcard)." ;;
esac

cd "$PROJECT_DIR"
[ -f package.json ] || fail "package.json is missing."
[ -f package-lock.json ] || fail "package-lock.json is missing."

printf 'Installing native Android Node.js and Git...\n'
pkg update -y
pkg install -y nodejs git

node -e "const major = Number(process.versions.node.split('.')[0]); if (process.platform !== 'android') { console.error('Native Termux Node.js is required; proot Linux is not supported.'); process.exit(1); } if (major < 20) { console.error('SillyTavern requires Node.js 20 or newer.'); process.exit(1); }"

printf 'Installing dependencies for this Android device...\n'
# npm ci replaces any copied desktop node_modules with a clean native install.
npm ci --omit=dev --ignore-scripts --no-audit --no-fund --loglevel=error --no-progress

# Keep start.sh from repeating the same dependency installation on first launch.
if command -v sha256sum >/dev/null 2>&1; then
    LOCK_HASH="$(sha256sum package-lock.json)"
    printf '%s\n' "${LOCK_HASH%% *}" > node_modules/.package-lock.sha256
fi

if [ -f "$CONFIG_PATH" ]; then
    printf 'Keeping the existing Android configuration: %s\n' "$CONFIG_PATH"
else
    printf 'Creating an Android-specific configuration...\n'
    node --input-type=module <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import yaml from 'yaml';

const configPath = path.resolve('config.termux.yaml');
const sourcePath = fs.existsSync('config.yaml') ? 'config.yaml' : 'default/config.yaml';
const config = yaml.parse(fs.readFileSync(sourcePath, 'utf8'));

if (!config || typeof config !== 'object' || Array.isArray(config)) {
    throw new Error(`Invalid configuration in ${sourcePath}`);
}

// Keep user data portable and limit network, startup, and model-download overhead.
config.dataRoot = './data';
config.listen = false;
config.browserLaunch = { ...config.browserLaunch, enabled: false };
config.extensions = {
    ...config.extensions,
    autoUpdate: false,
    models: { ...config.extensions?.models, autoDownload: false },
};
config.enableServerPluginsAutoUpdate = false;
config.performance = {
    ...config.performance,
    lazyLoadCharacters: true,
    useDiskCache: true,
};

fs.writeFileSync(configPath, yaml.stringify(config), { mode: 0o600 });
console.log(`Created ${configPath} from ${sourcePath}`);
NODE
fi

chmod +x "$PROJECT_DIR/start-termux.sh"

# Termux:Widget exposes this as a one-tap home-screen launcher when installed.
SHORTCUT_PATH="$HOME/.shortcuts/SillyTavern"
mkdir -p "$HOME/.shortcuts"
{
    printf '#!%s/bin/bash\n' "$PREFIX"
    printf 'exec %q\n' "$PROJECT_DIR/start-termux.sh"
} > "$SHORTCUT_PATH"
chmod 700 "$SHORTCUT_PATH"

printf '\nInstallation complete.\n'
printf 'Start SillyTavern with: bash %q\n' "$PROJECT_DIR/start-termux.sh"
printf 'Open the local URL printed at startup, then select "Add to Home screen" in the browser menu for an app icon.\n'
printf 'With Termux:Widget installed, %s is available as a one-tap launcher.\n' "$SHORTCUT_PATH"
printf 'For reliable background operation, set Termux battery usage to Unrestricted in Android settings.\n'
