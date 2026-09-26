#!/bin/sh
#
# Canonical llama.vscode settings validation.
# Every model reference in sources/config/llama-vscode-settings.json must be real:
# a remote entry must name a model its router capture lists, and a locally
# started entry must point at a loopback endpoint and load a model the athena
# cache already holds.
# This is the regression guard against the config drift that made the previous
# settings name models the routers no longer serve.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

python3 - "$REPOSITORY_ROOT" <<'PYTHON_SCRIPT'
import json
import os
import re
import sys

root = sys.argv[1]
fragment_path = os.path.join(root, "sources/config/llama-vscode-settings.json")

fragment = json.load(open(fragment_path))

# Endpoint -> capture file. The captures are the source of truth for model ids.
captures = {
    "http://beast.lan:2001": "dataflow.in/endpoints/beast-models.json",
    "http://beast.lan:2002": "dataflow.in/endpoints/beast-cpu-models.json",
    "http://athena.lan:2001": "dataflow.in/endpoints/athena-models.json",
}

served = {}
for endpoint, relative in captures.items():
    path = os.path.join(root, relative)
    data = json.load(open(path))
    served[endpoint] = {model["id"] for model in data["data"]}

# A locally started server runs on this host against the athena model cache.
LOCAL_HOSTS = ("127.0.0.1", "localhost")
LOCAL_CATALOG = "http://athena.lan:2001"

failures = []


def check(label, entry):
    endpoint = entry.get("endpoint", "")
    model = entry.get("aiModel", "")
    command = entry.get("localStartCommand", "")

    if command:
        if not any(host in endpoint for host in LOCAL_HOSTS):
            failures.append("%s: locally started model has a non-local endpoint %s" % (label, endpoint))
        match = re.search(r"-hf\s+'([^']+)'", command)
        if not match:
            failures.append("%s: localStartCommand has no quoted -hf repo spec" % label)
            return
        repo = match.group(1)
        if repo not in served[LOCAL_CATALOG]:
            failures.append("%s: locally started model %s is not in the athena catalog" % (label, repo))
        return

    if endpoint not in served:
        failures.append("%s: unknown endpoint %s" % (label, endpoint))
        return
    if model not in served[endpoint]:
        failures.append("%s: %s does not serve %s" % (label, endpoint, model))


list_keys = [
    "completion_models_list",
    "chat_models_list",
    "tools_models_list",
    "embeddings_models_list",
]
checked = 0
for key in list_keys:
    for entry in fragment.get("llama-vscode." + key, []):
        check("%s / %s" % (key, entry.get("name")), entry)
        checked += 1

for env in fragment.get("llama-vscode.envs_list", []):
    for role in ("completion", "chat", "tools", "embeddings"):
        entry = env.get(role)
        if entry:
            check("env %s / %s" % (env.get("name"), role), entry)
            checked += 1

# An env must always carry completion and chat; tools and embeddings are optional.
for env in fragment.get("llama-vscode.envs_list", []):
    if not env.get("completion"):
        failures.append("env %s: missing completion" % env.get("name"))
    if not env.get("chat"):
        failures.append("env %s: missing chat" % env.get("name"))

if failures:
    for failure in failures:
        print("03-llama-vscode: " + failure, file=sys.stderr)
    raise SystemExit("03-llama-vscode: FAILED")

print("03-llama-vscode: ok (%d model references verified against captures)" % checked)
PYTHON_SCRIPT
