#!/bin/sh
#
# Project test runner.
# Runs every tests/*.sh script and writes the transcript to
# logs/YYYY-MM-DD-HH-MM-SS-test-run.log, then prints it.
# Exits nonzero when any test fails.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
NAME_STAMP=$(date +%Y-%m-%d-%H-%M-%S)
FILE_LOG="$REPOSITORY_ROOT/logs/$NAME_STAMP-test-run.log"

mkdir -p "$REPOSITORY_ROOT/logs"

FAILURE=0

{
    echo "=== test-run $NAME_STAMP"
    for FILE_TEST in "$REPOSITORY_ROOT"/tests/*.sh; do
        NAME_TEST=$(basename "$FILE_TEST")
        echo "=== $NAME_TEST"
        if sh "$FILE_TEST"; then
            echo "PASS $NAME_TEST"
        else
            echo "FAIL $NAME_TEST"
            FAILURE=1
        fi
    done
    if [ "$FAILURE" -ne 0 ]; then
        echo "tests-run: FAILED"
    else
        echo "tests-run: ok"
    fi
} >"$FILE_LOG" 2>&1

cat "$FILE_LOG"

if [ "$FAILURE" -ne 0 ]; then
    exit 1
fi
exit 0
