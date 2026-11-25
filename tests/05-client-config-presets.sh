#!/bin/sh
#
# Client-config and preset consistency.
#
# A client config that names a model the router does not serve, or a context
# the preset does not provide, fails at the moment a person is trying to work.
# Those failures are silent here: the captures are the source of truth for
# model ids, and the tracked presets are the source of truth for context and
# parallelism. This test keeps the two in step before anything reaches a host.
#
# It checks, against the tracked presets in sources/config/:
#
#   1. Every remote model a client config names is a preset alias or a preset
#      key in the matching tracked preset.
#   2. The contextWindow a client config declares does not exceed the preset's
#      per-slot context (ctx-size divided by parallel).
#   3. No preset names a quantifier (UD-Q4_K_XL and the like) that the preset
#      key does not carry; a key naming a quant the cache lacks is what made
#      the athena r1 preset fail to load.
#   4. The live-state claims in the endpoints map match the tracked presets.
#
# Tier: portable. It reads repository files only.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"

skip_unless_tool python3

python3 - "$REPOSITORY_ROOT" <<'PYTHON_SCRIPT'
import json
import os
import re
import sys

ROOT = sys.argv[1]

# Endpoint base URL -> tracked preset file, and the preset's default parallel.
PRESETS = {
    "http://beast.lan:2001": "sources/config/beast-config.applied.ini",
    "http://beast.lan:2002": "sources/config/beast-config-cpu.applied.ini",
    "http://athena.lan:2001": "sources/config/athena-config.applied.ini",
}

failures = []


def read_preset(path):
    """Return {section_key: {key: value}} plus the [*] default block."""
    sections = {}
    current = None
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            match = re.match(r"^\[(.+)\]$", line)
            if match:
                current = match.group(1)
                sections[current] = {}
                continue
            if current is None:
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                sections[current][key.strip()] = value.strip()
    return sections


def resolve(endpoint, sections):
    """Return the set of acceptable model ids for one endpoint.

    A preset key may name a UD- selector (unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL)
    while the router reports the resolved file quant
    (unsloth/gpt-oss-20b-GGUF:Q4_K_XL). A client uses the reported id or the
    alias, so both the key and its de-UD- form are acceptable.
    """
    known = set()
    for key, values in sections.items():
        if key == "*":
            continue
        known.add(key)
        # The router resolves a UD- selector to the file's quant.
        if ":" in key:
            repo, quant = key.rsplit(":", 1)
            if quant.startswith("UD-"):
                known.add(repo + ":" + quant[3:])
        alias = values.get("alias")
        if alias:
            known.add(alias)
    return known


def per_slot_context(sections, section):
    """Return the per-slot context a preset section provides."""
    defaults = sections.get("*", {})
    values = sections.get(section, {})
    raw = values.get("ctx-size", defaults.get("ctx-size"))
    if raw is None:
        return None
    try:
        total = int(raw)
    except ValueError:
        return None
    parallel = values.get("parallel", defaults.get("parallel", "1"))
    try:
        divisor = int(parallel)
    except ValueError:
        divisor = 1
    if divisor < 1:
        divisor = 1
    return total // divisor


presets = {endpoint: read_preset(path) for endpoint, path in PRESETS.items()}

# --- 1 and 2: client configs name a real model and a reachable context ----

def check_llama_vscode():
    path = os.path.join(ROOT, "sources/config/llama-vscode-settings.json")
    with open(path, encoding="utf-8") as handle:
        fragment = json.load(handle)
    keys = [k for k in fragment if k.startswith("llama-vscode.") and k.endswith("_list")]
    for key in keys:
        for entry in fragment[key]:
            endpoint = entry.get("endpoint")
            model = entry.get("aiModel")
            if not endpoint or not model:
                continue
            if endpoint not in presets:
                continue
            sections = presets[endpoint]
            if model not in resolve(endpoint, sections):
                failures.append(
                    "llama-vscode %s: %s is not a preset or alias in %s"
                    % (key, model, PRESETS[endpoint])
                )
    return len(keys)


def check_dsh():
    path = os.path.join(ROOT, "sources/config/dsh-settings-beast.example.yaml")
    try:
        import yaml
    except ImportError:
        return 0
    with open(path, encoding="utf-8") as handle:
        document = yaml.safe_load(handle)
    providers = document.get("llm-pi-ai", {}).get("providers", {})
    checked = 0
    for name, provider in providers.items():
        base = provider.get("baseURL", "")
        # The baseURL carries a trailing /v1; the preset table uses the bare host.
        endpoint = base[:-3] if base.endswith("/v1") else base
        if endpoint not in presets:
            continue
        sections = presets[endpoint]
        for model in provider.get("models", []):
            model_id = model.get("id")
            window = model.get("contextWindow")
            checked += 1
            if model_id not in resolve(endpoint, sections):
                failures.append(
                    "dsh %s: %s is not a preset or alias in %s"
                    % (name, model_id, PRESETS[endpoint])
                )
                continue
            available = None
            if model_id in sections and model_id != "*":
                available = per_slot_context(sections, model_id)
            if available is None:
                # A preset reached by alias or by its resolved quant: find the
                # section that carries it, either as its key or as its alias.
                for section, values in sections.items():
                    if section == "*":
                        continue
                    if values.get("alias") == model_id:
                        available = per_slot_context(sections, section)
                        break
                    if ":" in section:
                        repo, quant = section.rsplit(":", 1)
                        if quant.startswith("UD-") and repo + ":" + quant[3:] == model_id:
                            available = per_slot_context(sections, section)
                            break
            if window is not None and available is not None and window > available:
                failures.append(
                    "dsh %s: %s declares contextWindow %s but the preset provides %s per slot"
                    % (name, model_id, window, available)
                )
    return checked


# --- 3: every preset section carries the alias its client config uses -----

def check_aliases():
    """A preset section needs an alias when a client config reaches it by name.

    The UD- selector in a preset key is intentional: the archives mirror the
    host config.ini verbatim. What matters is that the alias a client uses
    actually resolves, so a client that names a model the router cannot match
    is caught here rather than at a person's keyboard.
    """
    problems = 0
    for endpoint, sections in presets.items():
        for section, values in sections.items():
            if section == "*":
                continue
            if not values.get("alias"):
                problems += 1
                failures.append(
                    "%s: preset %s has no alias; clients must then use the full "
                    "reported id" % (PRESETS[endpoint], section)
                )
    return problems


# --- 4: the endpoints map's live claims match the tracked presets ---------

def check_endpoints_map():
    path = os.path.join(ROOT, "documents/07-endpoints-map.md")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    problems = 0
    # The map's Endpoints table must not still claim a parallel value the
    # tracked preset contradicts.
    for endpoint, sections in presets.items():
        defaults = sections.get("*", {})
        actual = defaults.get("parallel", "1")
        # Find the row for this endpoint in the table.
        for line in text.splitlines():
            if "|" not in line or "http" not in line:
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) < 5:
                continue
            if endpoint.replace("http://", "") in cells[1] or endpoint in " ".join(cells):
                declared = cells[4]
                if declared != actual:
                    problems += 1
                    failures.append(
                        "endpoints map: %s row declares parallel %s but the tracked preset runs %s"
                        % (endpoint, declared, actual)
                    )
    return problems


count_vscode = check_llama_vscode()
count_dsh = check_dsh()
check_aliases()
check_endpoints_map()

if failures:
    for failure in failures:
        print("05-client-configs: " + failure, file=sys.stderr)
    raise SystemExit(1)

print(
    "05-client-configs: ok (%d llama.vscode lists, %d DSH models, %d preset files)"
    % (count_vscode, count_dsh, len(PRESETS))
)
PYTHON_SCRIPT

pass_test "05-client-configs"
