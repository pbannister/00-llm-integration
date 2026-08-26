#!/bin/sh
#
# Configuration validation.
# Parses the JSON captures, the example YAML, and the imported ini files.
# Requires python3 with yaml for the YAML check; skips that check with WARN
# when unavailable (tool-gated).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

FAILURE=0

# JSON captures must parse and list models.
python3 - <<'PY'
import json
for name in ("beast", "athena"):
    path = f"dataflow.in/endpoints/{name}-models.json"
    try:
        data = json.load(open(path))
        count = len(data["data"])
        if count == 0:
            raise SystemExit(f"{name}: empty model list")
        print(f"01-configs: {name}-models.json parses ({count} models)")
    except Exception as error:
        raise SystemExit(f"01-configs: {name} capture invalid: {error}")
PY
if [ "$?" -ne 0 ]; then
    FAILURE=1
fi

# The example DSH settings must parse as YAML and carry the compat block.
if python3 -c 'import yaml' 2>/dev/null; then
    python3 - <<'PY'
import yaml
path = "sources/config/dsh-settings-beast.example.yaml"
data = yaml.safe_load(open(path))
provider = data["llm-pi-ai"]["providers"]["beast"]
assert provider["api"] == "openai-completions", "api must be openai-completions"
assert provider["baseURL"] == "http://beast.lan:2001/v1", "baseURL mismatch"
assert provider["compat"]["supportsDeveloperRole"] is False
assert provider["compat"]["maxTokensField"] == "max_tokens"
for model in provider["models"]:
    assert "contextWindow" in model, f"model {model['id']} lacks contextWindow"
    assert "maxTokens" in model, f"model {model['id']} lacks maxTokens"
    assert model["maxTokens"] < model["contextWindow"], f"model {model['id']}: maxTokens >= contextWindow"
print(f"01-configs: dsh-settings-beast.example.yaml valid ({len(provider['models'])} models)")
PY
    if [ "$?" -ne 0 ]; then
        FAILURE=1
    fi
else
    echo '01-configs: WARN python3 yaml module missing; YAML check skipped'
fi

# Imported ini files must exist.
for FILE_INI in sources/models/config-beast.ini sources/models/config-athena.ini; do
    if [ ! -s "$REPOSITORY_ROOT/$FILE_INI" ]; then
        echo "01-configs: missing $FILE_INI" >&2
        FAILURE=1
    fi
done

if [ "$FAILURE" -ne 0 ]; then
    echo '01-configs: FAILED' >&2
    exit 1
fi

echo '01-configs: ok'
exit 0
