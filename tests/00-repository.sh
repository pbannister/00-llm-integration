#!/bin/sh
#
# Repository structure check.
# Verifies the required directories exist and the canonical files are present.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

FAILURE=0

for DIRECTORY in prompts documents records tools sources scripts tests dataflow.in dataflow.out logs site.in site.out; do
    if [ ! -d "$REPOSITORY_ROOT/$DIRECTORY" ]; then
        echo "00-repository: missing directory $DIRECTORY" >&2
        FAILURE=1
    fi
done

for FILE in README.md TODO.md Makefile package.json \
    prompts/01-contract.md prompts/02-workflow.md prompts/03-conventions.md \
    prompts/features/00-features.md prompts/tasks/00-tasks.md \
    documents/07-endpoints-map.md documents/08-model-catalog.md \
    tools/aider-rules.md scripts/tests-run.sh scripts/endpoints-capture.sh \
    sources/config/dsh-settings-beast.example.yaml; do
    if [ ! -f "$REPOSITORY_ROOT/$FILE" ]; then
        echo "00-repository: missing file $FILE" >&2
        FAILURE=1
    fi
done

for FILE_CAPTURE in dataflow.in/endpoints/beast-models.json dataflow.in/endpoints/athena-models.json; do
    if [ ! -s "$REPOSITORY_ROOT/$FILE_CAPTURE" ]; then
        echo "00-repository: missing or empty capture $FILE_CAPTURE (run make capture)" >&2
        FAILURE=1
    fi
done

if [ "$FAILURE" -ne 0 ]; then
    echo '00-repository: FAILED' >&2
    exit 1
fi

echo '00-repository: ok'
exit 0
