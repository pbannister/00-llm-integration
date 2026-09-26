#!/bin/sh
#
# Merge the canonical llama.vscode settings into the VS Code user settings.
#
# The canonical fragment lives in sources/config/llama-vscode-settings.json.
# Only the keys present in that fragment are replaced; comments, formatting,
# and every unrelated setting in the target survive untouched.
#
# Usage:
#   sh scripts/llama-vscode-config-apply.sh            apply and write
#   sh scripts/llama-vscode-config-apply.sh --dry-run  validate without writing
#
# Target selection:
#   VSCODE_SETTINGS_FILE=/path/to/settings.json   override the default target
#
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

FILE_FRAGMENT="$REPOSITORY_ROOT/sources/config/llama-vscode-settings.json"
FILE_TARGET="${VSCODE_SETTINGS_FILE:-$HOME/.config/Code/User/settings.json}"

NAME_MODE="apply"
if [ "${1:-}" = "--dry-run" ]; then
    NAME_MODE="dry-run"
fi

if [ ! -f "$FILE_FRAGMENT" ]; then
    echo "llama-vscode-config-apply: missing fragment $FILE_FRAGMENT" >&2
    exit 1
fi

if [ ! -f "$FILE_TARGET" ]; then
    echo "llama-vscode-config-apply: missing target $FILE_TARGET" >&2
    exit 1
fi

if [ "$NAME_MODE" = "apply" ]; then
    NAME_STAMP=$(date +%Y%m%d-%H%M%S)
    FILE_BACKUP="$FILE_TARGET.bak-$NAME_STAMP"
    cp "$FILE_TARGET" "$FILE_BACKUP"
    echo "llama-vscode-config-apply: backup $FILE_BACKUP"
fi

python3 - "$FILE_FRAGMENT" "$FILE_TARGET" "$NAME_MODE" <<'PYTHON_SCRIPT'
import json
import re
import sys

fragment_path, target_path, mode = sys.argv[1], sys.argv[2], sys.argv[3]


def skip_whitespace(text, index):
    while index < len(text) and text[index] in " \t\r\n":
        index += 1
    return index


def scan_string(text, index):
    index += 1
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == '"':
            return index + 1
        index += 1
    raise ValueError("unterminated string")


def scan_value_end(text, index):
    index = skip_whitespace(text, index)
    char = text[index]
    if char == '"':
        return scan_string(text, index)
    if char in "[{":
        depth = 0
        while index < len(text):
            current = text[index]
            if current == '"':
                index = scan_string(text, index)
                continue
            if current in "[{":
                depth += 1
            elif current in "]}":
                depth -= 1
                if depth == 0:
                    return index + 1
            index += 1
        raise ValueError("unterminated array or object")
    while index < len(text) and text[index] not in ",}]\r\n":
        index += 1
    return index


def find_root_bounds(text):
    start = text.find("{")
    if start == -1:
        raise ValueError("no root object")
    depth = 0
    index = start
    while index < len(text):
        char = text[index]
        if char == '"':
            index = scan_string(text, index)
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return start, index
        index += 1
    raise ValueError("unterminated root object")


def find_key(text, key):
    token = '"%s"' % key
    cursor = 0
    while True:
        found = text.find(token, cursor)
        if found == -1:
            return -1
        after = skip_whitespace(text, found + len(token))
        if after < len(text) and text[after] == ":":
            return found
        cursor = found + len(token)


def line_indent(text, index):
    line_start = text.rfind("\n", 0, index) + 1
    indent = ""
    while line_start + len(indent) < len(text) and text[line_start + len(indent)] in " \t":
        indent += text[line_start + len(indent)]
    return indent


def serialize(value, indent):
    lines = json.dumps(value, indent=4, ensure_ascii=False).split("\n")
    return ("\n" + indent).join(lines)


def strip_jsonc(text):
    # Remove comments and trailing commas so the result can be parsed strictly.
    pieces = []
    index = 0
    while index < len(text):
        char = text[index]
        if char == '"':
            end = scan_string(text, index)
            pieces.append(text[index:end])
            index = end
            continue
        if char == "/" and text[index:index + 2] == "//":
            while index < len(text) and text[index] not in "\r\n":
                index += 1
            continue
        if char == "/" and text[index:index + 2] == "/*":
            index += 2
            while index + 1 < len(text) and text[index:index + 2] != "*/":
                index += 1
            index += 2
            continue
        pieces.append(char)
        index += 1

    uncommented = "".join(pieces)
    result = []
    index = 0
    while index < len(uncommented):
        char = uncommented[index]
        if char == '"':
            end = scan_string(uncommented, index)
            result.append(uncommented[index:end])
            index = end
            continue
        if char == ",":
            lookahead = skip_whitespace(uncommented, index + 1)
            if lookahead < len(uncommented) and uncommented[lookahead] in "}]":
                index += 1
                continue
        result.append(char)
        index += 1
    return "".join(result)


fragment = json.load(open(fragment_path))
target = open(target_path).read()

# The target is JSONC; a strict parse proves it is loadable before the merge.
json.loads(strip_jsonc(target))

updated = target
inserted_keys = []
replaced_keys = []

for key in fragment:
    position = find_key(updated, key)
    if position == -1:
        inserted_keys.append(key)
        continue
    indent = line_indent(updated, position)
    colon = skip_whitespace(updated, position + len('"%s"' % key))
    value_start = skip_whitespace(updated, colon + 1)
    value_end = scan_value_end(updated, value_start)
    updated = updated[:value_start] + serialize(fragment[key], indent) + updated[value_end:]
    replaced_keys.append(key)

if inserted_keys:
    root_start, root_end = find_root_bounds(updated)
    head = updated[:root_end].rstrip()
    tail = updated[root_end:]
    if not head.endswith(("{", ",")):
        head += ","
    for key in inserted_keys:
        head += "\n    %s: %s," % (json.dumps(key), serialize(fragment[key], "    "))
    head = head.rstrip(",")
    updated = head + "\n" + tail

json.loads(strip_jsonc(updated))

print("llama-vscode-config-apply: replaced %d keys: %s" % (len(replaced_keys), ", ".join(replaced_keys)))
if inserted_keys:
    print("llama-vscode-config-apply: inserted %d keys: %s" % (len(inserted_keys), ", ".join(inserted_keys)))

if mode == "dry-run":
    print("llama-vscode-config-apply: dry-run, target not written")
    raise SystemExit(0)

open(target_path, "w").write(updated)
print("llama-vscode-config-apply: wrote %s" % target_path)
PYTHON_SCRIPT
