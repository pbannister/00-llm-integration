#!/bin/sh
#
# Refresh the live router captures into dataflow.in/endpoints/.
# Live-state facts in this project are derived from these files.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
DIRECTORY_OUTPUT="$REPOSITORY_ROOT/dataflow.in/endpoints"

mkdir -p "$DIRECTORY_OUTPUT"

curl -s -m 10 http://beast.lan:2001/v1/models -o "$DIRECTORY_OUTPUT/beast-models.json"
curl -s -m 10 http://beast.lan:2002/v1/models -o "$DIRECTORY_OUTPUT/beast-cpu-models.json"
curl -s -m 10 http://athena.lan:2001/v1/models -o "$DIRECTORY_OUTPUT/athena-models.json"

echo "endpoints-capture: wrote beast-models.json, beast-cpu-models.json and athena-models.json"
exit 0
