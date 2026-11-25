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

printf '%s\n' "$CONFIG" | grep -q . || exit 2
echo "preset-keys-check: $CONFIG against $BINARY"

# A BAD key must fail the check: llama.cpp refuses to start the router on an
# unknown preset key, so a silent pass here would let the installer restart a
# service that cannot load. The count is collected in a file because the
# pipeline below runs in a subshell and cannot set a variable.
DIRECTORY_TEMP=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEMP"' EXIT INT TERM

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
                printf 'x\n' >> "$DIRECTORY_TEMP/bad"
            fi
            ;;
    esac
done

if [ -s "$DIRECTORY_TEMP/bad" ]; then
    count_bad=$(wc -l < "$DIRECTORY_TEMP/bad" | tr -d ' ')
    echo "preset-keys-check: $count_bad BAD key(s); the router would refuse to start" >&2
    exit 1
fi

echo "preset-keys-check: ok (every key is a known llama-server option)"
exit 0
