#!/bin/sh
#
# site-pages.sh: build the standard project page set into site.out/.
#
# Reads the live routers for the dashboard, sanitizes the published text
# (the labs deploy gate refuses private IPs, usernames, and home paths —
# see homelab documents/09-project-pages-conventions.md), then runs the
# shared generators:
#   - scripts/site-condense.sh  -> todo.html, prompts.html, documents.html,
#                                  records.html + full-text pages (from a
#                                  sanitized mirror of the markdown trees)
#   - scripts/site-build.sh     -> index.html, dashboard.html (from the
#                                  template + static/generated inputs)
#
# Usage: site-pages.sh
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

DIRECTORY_SOURCE="$REPOSITORY_ROOT/dataflow.out/site-source"
DIRECTORY_INPUT_BUILD="$REPOSITORY_ROOT/dataflow.out/site-in"
DIRECTORY_OUTPUT="$REPOSITORY_ROOT/site.out"

# --- 1. sanitized mirror of the markdown trees -------------------------------
rm -rf "$DIRECTORY_SOURCE" "$DIRECTORY_INPUT_BUILD"
mkdir -p "$DIRECTORY_SOURCE" "$DIRECTORY_INPUT_BUILD"

for TREE in prompts documents records; do
    cp -r "$REPOSITORY_ROOT/$TREE" "$DIRECTORY_SOURCE/$TREE"
done
cp "$REPOSITORY_ROOT/TODO.md" "$DIRECTORY_SOURCE/TODO.md"
[ -f "$REPOSITORY_ROOT/PHASES.md" ] && cp "$REPOSITORY_ROOT/PHASES.md" "$DIRECTORY_SOURCE/PHASES.md"

# Redact what the deploy gate refuses: private LAN IPs -> hostname or "lan",
# usernames -> "owner", home paths -> "~".
find "$DIRECTORY_SOURCE" -type f \( -name '*.md' -o -name 'TODO.md' \) | while read -r FILE; do
    sed -i \
        -e 's/192\.168\.8\.186/minerva.lan/g' \
        -e 's/192\.168\.8\.21/athena.lan/g' \
        -e 's/192\.168\.8\.20/beast.lan/g' \
        -e 's/192\.168\.[0-9][0-9]*\.[0-9][0-9]*/lan/g' \
        -e 's/172\.\(1[6-9]\|2[0-9]\|3[01]\)\.[0-9][0-9]*\.[0-9][0-9]*/lan/g' \
        -e 's/10\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/lan/g' \
        -e 's/preston/owner/g' \
        -e 's|/home/[a-zA-Z][a-zA-Z0-9_-]*|~|g' \
        "$FILE"
done

# --- 2. dashboard with live values -------------------------------------------
{
    echo '<h1>Dashboard</h1>'
    echo "<p>Live state captured $(date +%Y-%m-%d) by <code>scripts/site-pages.sh</code>.</p>"
    echo '<ul>'
    for HOST in beast.lan athena.lan; do
        COUNT=$(curl -s -m 5 "http://$HOST:2001/v1/models" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['data']))" 2>/dev/null || echo 'unreachable')
        ALIASED=$(curl -s -m 5 "http://$HOST:2001/v1/models" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for m in d['data'] if m.get('aliases')))" 2>/dev/null || echo 0)
        echo "  <li><code>$HOST</code> router: $COUNT models ($ALIASED aliased).</li>"
    done
    echo '  <li>KV cache: q8_0/q8_0 common; q4_0 V on the gemma presets (applied 2026-08-26).</li>'
    echo '  <li>Prompt reuse: <code>cache-reuse 256</code>; <code>parallel 4</code> on both routers.</li>'
    echo '  <li>Embeddings endpoint: live on athena (<code>nomic-embed</code>).</li>'
    echo '</ul>'
} > "$DIRECTORY_INPUT_BUILD/dashboard.txt"

cp "$REPOSITORY_ROOT/site.in/template.html" "$DIRECTORY_INPUT_BUILD/template.html"
cp "$REPOSITORY_ROOT/site.in/index.txt" "$DIRECTORY_INPUT_BUILD/index.txt"

# --- 3. generate --------------------------------------------------------------
SITE_SOURCE_ROOT="$DIRECTORY_SOURCE" sh "$DIRECTORY_SCRIPT/site-condense.sh"
sh "$DIRECTORY_SCRIPT/site-build.sh" "$DIRECTORY_INPUT_BUILD" "$DIRECTORY_OUTPUT"

echo "site-pages: built the standard page set into $DIRECTORY_OUTPUT"
exit 0
