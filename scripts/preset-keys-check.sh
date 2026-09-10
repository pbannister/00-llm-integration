#!/bin/sh
#
# preset-keys-check.sh: validate a llama.cpp preset .ini against a binary.
#
# llama.cpp validates preset keys against its own CLI option names
# (common/preset.cpp) and refuses to start the router on an unknown key, e.g.
#   failed to initialize router models: option 'mmap' not recognized in preset '*'
# Upstream renames/removals (such as --mmap -> --load-mode in 0.4.0) therefore
# break existing presets on upgrade. Run this before restarting services after
# a llama.cpp rebuild.
#
# Usage: preset-keys-check.sh [PATH_LLAMA_SERVER] [PATH_CONFIG]
set -eu

BINARY=${1:-/usr/local/bin/llama-server}
CONFIG=${2:-/usr/local/etc/config.ini}

HELP=$("$BINARY" --help 2>&1 || true)
STATUS=0

printf '%s\n' "$CONFIG" | grep -q . || exit 2
echo "preset-keys-check: $CONFIG against $BINARY"

grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$CONFIG" | while IFS= read -r LINE; do
    case "$LINE" in
        \[*\]) continue ;;
        *=*)
            KEY=$(printf '%s' "$LINE" | sed 's/^[[:space:]]*//; s/[[:space:]]*=.*//')
            VALUE=$(printf '%s' "$LINE" | sed 's/^[^=]*=[[:space:]]*//')
            if printf '%s' "$HELP" | grep -qE -- "--?$KEY([ ,]|$)"; then
                echo "  ok   $KEY = $VALUE"
            else
                echo "  BAD  $KEY = $VALUE"
            fi
            ;;
    esac
done

echo "preset-keys-check: review any BAD keys before restarting the service"
exit 0
