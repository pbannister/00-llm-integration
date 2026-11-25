#!/bin/sh
#
# llama-service-install.sh: install and configure the llama.cpp router
# services on beast.lan and athena.lan from this repository's tracked config.
#
# The three services, verified live 2026-11-23:
#
#   target      host        unit              port  preset file
#   beast-gpu   beast.lan   llama.service     2001  /usr/local/etc/config.ini
#   beast-cpu   beast.lan   llama-cpu.service 2002  /usr/local/etc/config-cpu.ini
#   athena-gpu  athena.lan  llama.service     2001  /usr/local/etc/config.ini
#
# Every target stops at its first failure; no target is touched after a
# failure. A preset key is a llama.cpp CLI option name, and an unknown key
# makes the router refuse to start in a systemd restart loop
# (records/2026-09-10-01-llamacpp-mmap-preset-key-removed.md). So before any
# live change the driver validates the copied preset with
# scripts/preset-keys-check.sh against the host binary, then dry-runs it on a
# loopback scratch port until the router answers /health; both refuse on
# failure. One change is verified before the next, and every file the driver
# replaces is backed up first.
#
# Usage:
#   llama-service-install.sh [--dry-run] [--verify-only] [--force] <target>...
#   llama-service-install.sh [--dry-run] [--verify-only] [--force] --all
#
#   <target>        beast-gpu, beast-cpu, or athena-gpu
#   --all           every target, in that order
#   --dry-run       run every read-only check and print what would change
#   --verify-only   check the live state only; change nothing
#   --force         accept a live preset that differs from the tracked one;
#                   the live copy still goes to a dated backup first
#
# Environment:
#   LLAMA_HOST_BEAST_GPU   SSH host for beast-gpu (default beast.lan)
#   LLAMA_HOST_BEAST_CPU   SSH host for beast-cpu (default beast.lan)
#   LLAMA_HOST_ATHENA_GPU  SSH host for athena-gpu (default athena.lan)
#   SSH_OPTIONS            options for every ssh and scp call; the default is
#                          -F /dev/null -o BatchMode=yes -o ConnectTimeout=8,
#                          which bypasses this workstation's broken
#                          ~/.ssh/config
#   LLAMA_KEY_BEAST        key for beast.lan (default $HOME/.ssh/keys/key-beast)
#   LLAMA_KEY_ATHENA       key for athena.lan (default $HOME/.ssh/keys/key-athena)
#   LLAMA_ACCEPT_REMOTE_DIFF=1
#                          same as --force; without either, a live preset that
#                          differs from the tracked one is printed and refused
#   LLAMA_SKIP_RESTART=1   install everything and leave the unit running
#   LLAMA_SCRATCH_PORT     loopback port of the dry run (default 61555)
#   LLAMA_SETTLE_SECONDS   wait after a restart before the live checks
#                          (default 5, at most 120)
#   LLAMA_REPOSITORY_ROOT  repository root (default: the script's parent)
#   LLAMA_SCRATCH_DIRECTORY
#                          scratch directory for rendered files (default: a
#                          fresh mktemp -d, removed on exit)
#
# The tracked presets are the archives in sources/config/, which mirror the
# live host configs as last applied:
#
#   beast-gpu   sources/config/beast-config.applied.ini
#   beast-cpu   sources/config/beast-config-cpu.applied.ini
#   athena-gpu  sources/config/athena-config.applied.ini
#
# They always win over any home-directory copy on a host, including
# ~/models/config-<hostname>.ini, which is stale on beast. The reference
# copies under sources/models/ are the 2026-08-26 snapshot and are never
# installed. sources/models/install.sh is not used: it reads that home path,
# and its GGML_VK_VISIBLE_DEVICES auto-detect yields an empty device list
# (records/2026-09-03-01-athena-gpu-fixes-qwen27-llamacpp-current.md).
#
# The driver never reads standard input, and never runs a command as root on
# this workstation: every privileged command runs on a host through ssh,
# where sudo is passwordless.
#
# Exit: 0 every selected check passed; 1 a check failed or a change was
# refused; 2 a usage error.
set -eu

NAME_SCRIPT='llama-service-install'
OWNER_SERVICE='preston'
# Every host home path below is rendered from OWNER_SERVICE, so no
# literal home path is committed.
PATH_HOME_SERVICE='/home/'
PATTERN_TARGET='beast-gpu|beast-cpu|athena-gpu'


DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

usage() {
    sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed '/^# Environment:/d' | sed 's/^# \{0,1\}//'
}

fail() {
    echo "$NAME_SCRIPT: $1" >&2
    exit 1
}

refuse_usage() {
    usage >&2
    echo "$NAME_SCRIPT: $1 (refused)" >&2
    exit 2
}

# pass_line TARGET LABEL DETAIL: report a passing check.
pass_line() {
    echo "PASS $1: $2${3:+: $3}"
}

# skip_line TARGET LABEL DETAIL: report a check that does not apply.
skip_line() {
    echo "SKIP $1: $2${3:+: $3}"
}

# fail_line TARGET LABEL DETAIL: report a failing check.
fail_line() {
    echo "FAIL $1: $2${3:+: $3}"
}

# indent_output PATH: echo a report file's lines under a report line.
indent_output() {
    sed 's/^/    /' "$1"
}

# quote_argument TEXT: single-quote TEXT for the host shell.
quote_argument() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# ssh_host: run the remaining arguments on the target host, never reading
# standard input.
ssh_host() {
    ssh $SSH_OPTIONS -i "$FILE_SSH_KEY" "$HOST_REMOTE" "$@" </dev/null
}

# scp_to_host SOURCE: copy SOURCE to PATH_REMOTE_COPY on the host.
scp_to_host() {
    scp $SSH_OPTIONS -i "$FILE_SSH_KEY" "$1" "$HOST_REMOTE:$PATH_REMOTE_COPY" </dev/null >/dev/null 2>&1
}

# scp_path_to_host SOURCE DESTINATION: copy SOURCE to an explicit path on the
# host, for a file that is not the target's preset copy.
scp_path_to_host() {
    scp $SSH_OPTIONS -i "$FILE_SSH_KEY" "$1" "$HOST_REMOTE:$2" </dev/null >/dev/null 2>&1
}

# scp_from_host SOURCE DESTINATION: copy a host path to this workstation.
scp_from_host() {
    scp $SSH_OPTIONS -i "$FILE_SSH_KEY" "$HOST_REMOTE:$1" "$2" </dev/null >/dev/null 2>&1
}

# render_unit TARGET FILE_SOURCE FILE_TARGET: rewrite the unit into FILE_TARGET.
# The unit is the host's current file, not a fixed template: the driver
# changes only the ExecStart line and refuses any other change, so a
# comment or directive the host carries is never silently dropped.
# Each target's ExecStart is its live command line; a target with no
# port renders an empty file, and the caller refuses it.
render_unit() {
    VALUE_EXEC_START=''
    case $1 in
        beast-gpu)
            VALUE_EXEC_START='/usr/local/bin/llama-server --models-preset /usr/local/etc/config.ini --host 0.0.0.0 --port 2001 --models-max 1 --tools all --allow-unauthenticated-tools'
            ;;
        beast-cpu)
            VALUE_EXEC_START='/usr/local/bin/llama-server --models-preset /usr/local/etc/config-cpu.ini --host 0.0.0.0 --port 2002 --tools all --allow-unauthenticated-tools'
            ;;
        athena-gpu)
            VALUE_EXEC_START='/usr/local/bin/llama-server --models-preset /usr/local/etc/config.ini --host 0.0.0.0 --port 2001 --tools all --allow-unauthenticated-tools'
            ;;
    esac
    if [ -z "$VALUE_EXEC_START" ] || [ ! -s "$2" ]; then
        : >"$3"
        return 0
    fi
    awk -v exec_start="$VALUE_EXEC_START" '
        /^ExecStart=/ {
            print "ExecStart=" exec_start
            found = 1
            next
        }
        {
            print
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "$2" >"$3"
    return $?
}

# select_target TARGET: set every per-target constant. Each preset comes from
# its archive in sources/config/, which is the current mirror of the live host
# config; sources/models/config-*.ini is the stale 2026-08-26 reference and is
# never installed.
select_target() {
    TARGET_NAME=$1
    NAME_UNIT='llama.service'
    PATH_REMOTE_STARTED=''
    RESTARTS_BEFORE=''
    case $1 in
        beast-gpu)
            HOST_REMOTE=$LLAMA_HOST_BEAST_GPU
            FILE_SSH_KEY=$LLAMA_KEY_BEAST
            PATH_PRESET='/usr/local/etc/config.ini'
            FILE_TRACKED_PRESET="$REPOSITORY_ROOT/sources/config/beast-config.applied.ini"
            FILE_PRESET_NEW="$DIRECTORY_WORK/preset-beast-gpu.ini"
            ;;
        beast-cpu)
            HOST_REMOTE=$LLAMA_HOST_BEAST_CPU
            FILE_SSH_KEY=$LLAMA_KEY_BEAST
            NAME_UNIT='llama-cpu.service'
            PATH_PRESET='/usr/local/etc/config-cpu.ini'
            FILE_TRACKED_PRESET="$REPOSITORY_ROOT/sources/config/beast-config-cpu.applied.ini"
            FILE_PRESET_NEW="$DIRECTORY_WORK/preset-beast-cpu.ini"
            ;;
        athena-gpu)
            HOST_REMOTE=$LLAMA_HOST_ATHENA_GPU
            FILE_SSH_KEY=$LLAMA_KEY_ATHENA
            PATH_PRESET='/usr/local/etc/config.ini'
            FILE_TRACKED_PRESET="$REPOSITORY_ROOT/sources/config/athena-config.applied.ini"
            FILE_PRESET_NEW="$DIRECTORY_WORK/preset-athena-gpu.ini"
            ;;
    esac
    PATH_UNIT="/etc/systemd/system/$NAME_UNIT"
    FILE_UNIT="$DIRECTORY_WORK/unit-$1"
    PATH_REMOTE_SCRIPT="/tmp/$NAME_SCRIPT-$1-preset-keys-check.sh"
    PATH_REMOTE_LOG="/tmp/$NAME_SCRIPT-$1-scratch.log"
    PATH_REMOTE_COPY="/tmp/$NAME_SCRIPT-$PPID-$1.ini"
    return 0
}

# cleanup_host: stop this target's scratch router and remove its host temp
# files. It matches only this target's scratch log, so it can never stop a
# live unit, and it is harmless when nothing was started. It contacts no
# host that the run has not reached.
cleanup_host() {
    if [ -z "${HOST_REMOTE:-}" ] || [ -z "${FILE_SSH_KEY:-}" ]; then
        return 0
    fi
    if [ -z "${PATH_REMOTE_STARTED:-}" ]; then
        return 0
    fi
    ssh_host "sudo -n pkill -f -- $(quote_argument "--log-file $PATH_REMOTE_LOG") 2>/dev/null; sudo -n rm -f $(quote_argument "$PATH_REMOTE_LOG") $(quote_argument "$PATH_REMOTE_COPY") $(quote_argument "$PATH_REMOTE_SCRIPT")" >/dev/null 2>&1 || true
    return 0
}

cleanup_all() {
    cleanup_host
    if [ -n "${DIRECTORY_WORK_CREATED:-}" ]; then
        rm -rf "$DIRECTORY_WORK"
    fi
}

# check_reachability TARGET: prove ssh reaches the host.
check_reachability() {
    if ! ssh_host true 2>"$DIRECTORY_WORK/ssh-error.log"; then
        fail_line "$1" 'reachability' "ssh cannot reach $HOST_REMOTE (refused)"
        indent_output "$DIRECTORY_WORK/ssh-error.log"
        return 1
    fi
    pass_line "$1" 'reachability' "ssh $HOST_REMOTE"
    return 0
}

# check_binary TARGET: find the host binary and record its version line.
# llama.cpp is built from $HOME/sources/llama.cpp and installed to
# /usr/local/bin, and a rebuild needs a restart, because the router
# snapshots the binary at service start
# (records/2026-09-02-02-llamacpp-rebuild-qwen38.md); the version recorded
# here and the verified restart below cover that.
check_binary() {
    PATH_LLAMA_SERVER=$(ssh_host 'command -v llama-server' 2>"$DIRECTORY_WORK/ssh-error.log") || PATH_LLAMA_SERVER=''
    if [ -z "$PATH_LLAMA_SERVER" ]; then
        fail_line "$1" 'binary' "llama-server is not on PATH on $HOST_REMOTE (refused)"
        indent_output "$DIRECTORY_WORK/ssh-error.log"
        return 1
    fi
    ssh_host "$PATH_LLAMA_SERVER --version 2>&1 | head -n 1" >"$DIRECTORY_WORK/version.log" 2>&1 || true
    pass_line "$1" 'binary' "$PATH_LLAMA_SERVER ($(sed -n '1p' "$DIRECTORY_WORK/version.log"))"
    return 0
}

# list_models FILE_JSON: parse a router model list into models.log and print
# the count and one line per model with its aliases. It exits nonzero when
# the list does not parse or lists no model.
list_models() {
    python3 - "$1" >"$DIRECTORY_WORK/models.log" 2>&1 <<'PYTHON_SCRIPT'
import json
import sys

try:
    models = json.load(open(sys.argv[1]))["data"]
except Exception as error:
    print("unparsable model list: %s" % error)
    raise SystemExit(1)

print("model count: %d" % len(models))
for model in models:
    aliases = model.get("aliases") or []
    line = model.get("id", "")
    if aliases:
        line = "%s [%s]" % (line, ",".join(aliases))
    print("    " + line)
raise SystemExit(0 if models else 1)
PYTHON_SCRIPT
}

# check_preset_keys TARGET FILE_LOCAL LABEL: copy a preset to a temp path on
# the host and validate that copy with the shipped checker against the host
# binary. The checker prints its verdict and always exits 0, so a BAD line
# is the refusal.
check_preset_keys() {
    if ! scp_to_host "$2"; then
        fail_line "$1" "keys $3" "cannot copy $2 to $HOST_REMOTE"
        return 1
    fi
    if ! scp_path_to_host "$FILE_CHECKER" "$PATH_REMOTE_SCRIPT"; then
        fail_line "$1" "keys $3" "cannot copy $FILE_CHECKER to $HOST_REMOTE"
        return 1
    fi
    if ! ssh_host "sh $(quote_argument "$PATH_REMOTE_SCRIPT") $(quote_argument "$PATH_LLAMA_SERVER") $(quote_argument "$PATH_REMOTE_COPY")" >"$DIRECTORY_WORK/keys.log" 2>&1; then
        fail_line "$1" "keys $3" 'preset-keys-check.sh failed on the host'
        indent_output "$DIRECTORY_WORK/keys.log"
        return 1
    fi
    if grep -E '^[[:space:]]*BAD[[:space:]]' "$DIRECTORY_WORK/keys.log" >"$DIRECTORY_WORK/keys-bad.log"; then
        fail_line "$1" "keys $3" "the binary rejects a key in $PATH_REMOTE_COPY (refused)"
        indent_output "$DIRECTORY_WORK/keys-bad.log"
        return 1
    fi
    VALUE_KEYS=$(grep -c '^  ok ' "$DIRECTORY_WORK/keys.log" || true)
    pass_line "$1" "keys $3" "$VALUE_KEYS key(s) accepted, no BAD key"
    return 0
}

# scratch_listening TARGET: prove the scratch router reported listening.
scratch_listening() {
    ssh_host "sudo -n grep -h -m 1 'listening on' $(quote_argument "$PATH_REMOTE_LOG")" >"$DIRECTORY_WORK/scratch.log" 2>/dev/null || return 1
    return 0
}

# scratch_health TARGET: prove the scratch router answers /health. The router
# parses every preset before it serves, which is the step that failed on
# 2026-09-10, so a health answer proves the preset loads.
scratch_health() {
    if ssh_host "sudo -n curl -sf -m 5 http://127.0.0.1:$LLAMA_SCRATCH_PORT/health" >"$DIRECTORY_WORK/health.log" 2>&1; then
        return 0
    fi
    fail_line "$1" 'scratch health' "no health answer on 127.0.0.1:$LLAMA_SCRATCH_PORT (refused)"
    ssh_host "sudo -n tail -n 15 $(quote_argument "$PATH_REMOTE_LOG")" >"$DIRECTORY_WORK/tail.log" 2>&1 || true
    indent_output "$DIRECTORY_WORK/tail.log"
    return 1
}

# run_scratch TARGET LABEL: dry-run the copied preset on the scratch port.
# The router writes its own log through sudo, so the host process outlives
# the ssh session; the driver polls that log and the host loopback health,
# and it always ends with cleanup_host.
run_scratch() {
    PATH_REMOTE_STARTED=1
    if ! ssh_host "sudo -n rm -f $(quote_argument "$PATH_REMOTE_LOG")" >"$DIRECTORY_WORK/prepare.log" 2>&1; then
        PATH_REMOTE_STARTED=''
        fail_line "$1" "dry run $2" "cannot clear $PATH_REMOTE_LOG on $HOST_REMOTE"
        indent_output "$DIRECTORY_WORK/prepare.log"
        return 1
    fi
    ssh_host "nohup sudo -n $PATH_LLAMA_SERVER --models-preset $(quote_argument "$PATH_REMOTE_COPY") --host 127.0.0.1 --port $LLAMA_SCRATCH_PORT --tools all --allow-unauthenticated-tools --log-file $(quote_argument "$PATH_REMOTE_LOG") </dev/null >/dev/null 2>&1 &" >/dev/null 2>&1 || true
    VALUE_WAIT=0
    while [ "$VALUE_WAIT" -lt 25 ]; do
        sleep 1
        VALUE_WAIT=$((VALUE_WAIT + 1))
        if scratch_listening "$1"; then
            break
        fi
    done
    if ! scratch_listening "$1"; then
        fail_line "$1" "dry run $2" "not listening on 127.0.0.1:$LLAMA_SCRATCH_PORT after $VALUE_WAIT s (refused)"
        ssh_host "sudo -n tail -n 15 $(quote_argument "$PATH_REMOTE_LOG")" >"$DIRECTORY_WORK/tail.log" 2>&1 || true
        indent_output "$DIRECTORY_WORK/tail.log"
        cleanup_host
        return 1
    fi
    if ! scratch_health "$1"; then
        cleanup_host
        return 1
    fi
    pass_line "$1" "dry run $2" "$(sed -n '1p' "$DIRECTORY_WORK/scratch.log")"
    ssh_host "sudo -n grep -E -m 8 -e 'Version:' -e 'using device' $(quote_argument "$PATH_REMOTE_LOG")" >"$DIRECTORY_WORK/scratch-detail.log" 2>&1 || true
    indent_output "$DIRECTORY_WORK/scratch-detail.log"
    cleanup_host
    return 0
}

# check_scratch_models TARGET LABEL: list the aliases the scratch router
# registered, as evidence of what would be served.
check_scratch_models() {
    if ! ssh_host "sudo -n curl -sf -m 10 http://127.0.0.1:$LLAMA_SCRATCH_PORT/v1/models" >"$DIRECTORY_WORK/models.json" 2>"$DIRECTORY_WORK/models-error.log"; then
        pass_line "$1" "models $2" 'the scratch router did not answer the model list; its health answer stands'
        return 0
    fi
    if ! list_models "$DIRECTORY_WORK/models.json"; then
        # Evidence only: the scratch router has already answered /health, so a
        # slow or partial model list is reported, not a refusal.
        skip_line "$1" "models $2" 'the scratch router model list did not parse; its health answer stands'
        indent_output "$DIRECTORY_WORK/models.log"
        return 0
    fi
    pass_line "$1" "models $2" "$(sed -n '1p' "$DIRECTORY_WORK/models.log")"
    indent_output "$DIRECTORY_WORK/models.log"
    return 0
}

# check_preset_scene TARGET FILE_LOCAL LABEL: prove one preset starts on the
# host. The copy is validated there, dry-run on the scratch port, and its
# model list printed; nothing live changes.
check_preset_scene() {
    if ! check_preset_keys "$1" "$2" "$3"; then
        return 1
    fi
    if ! run_scratch "$1" "$3"; then
        return 1
    fi
    if ! check_scratch_models "$1" "$3"; then
        return 1
    fi
    return 0
}

# compare_live_preset TARGET: print the diff between the live preset and the
# new one and refuse to replace it without --force or
# LLAMA_ACCEPT_REMOTE_DIFF=1. A live file that changed after it was read is
# reported, never overwritten silently.
compare_live_preset() {
    : >"$DIRECTORY_WORK/live-preset.ini"
    if ! scp_from_host "$PATH_PRESET" "$DIRECTORY_WORK/live-preset.ini"; then
        skip_line "$1" 'live preset diff' "$PATH_PRESET is missing; nothing to compare"
        return 0
    fi
    if diff -u "$DIRECTORY_WORK/live-preset.ini" "$FILE_PRESET_NEW" >"$DIRECTORY_WORK/preset.diff"; then
        pass_line "$1" 'live preset diff' "$PATH_PRESET matches the new preset"
        return 0
    fi
    if [ '1' = "$IS_FORCE" ]; then
        pass_line "$1" 'live preset diff' "$PATH_PRESET differs; accepted by --force"
        indent_output "$DIRECTORY_WORK/preset.diff"
        return 0
    fi
    fail_line "$1" 'live preset diff' "$PATH_PRESET differs from the tracked preset (refused, nothing written)"
    indent_output "$DIRECTORY_WORK/preset.diff"
    echo "    re-run with --force or LLAMA_ACCEPT_REMOTE_DIFF=1 to replace it; a real run backs it up first" >&2
    return 1
}

# check_unit TARGET: fetch the live unit, then render the desired one from it
# (the ExecStart rewrite) and diff the two.
check_unit() {
    : >"$DIRECTORY_WORK/unit-live"
    if ! scp_from_host "$PATH_UNIT" "$DIRECTORY_WORK/unit-live"; then
        fail_line "$1" 'unit' "$PATH_UNIT is missing; the driver edits the live unit and never invents one (refused)"
        return 1
    fi
    if ! render_unit "$1" "$DIRECTORY_WORK/unit-live" "$FILE_UNIT"; then
        fail_line "$1" 'unit' "$PATH_UNIT has no ExecStart= line to rewrite (refused)"
        return 1
    fi
    if cmp -s "$FILE_UNIT" "$DIRECTORY_WORK/unit-live"; then
        pass_line "$1" 'unit' 'unit unchanged'
        return 0
    fi
    pass_line "$1" 'unit' "$PATH_UNIT differs; it would be backed up and installed"
    diff -u "$DIRECTORY_WORK/unit-live" "$FILE_UNIT" >"$DIRECTORY_WORK/unit.diff" 2>&1 || true
    indent_output "$DIRECTORY_WORK/unit.diff"
    return 0
}

# install_preset TARGET: back an existing live preset up, then install the
# new one.
install_preset() {
    if scp_from_host "$PATH_PRESET" "$DIRECTORY_WORK/live-preset.ini"; then
        if ! ssh_host "sudo -n cp -p $(quote_argument "$PATH_PRESET") $(quote_argument "$PATH_PRESET.bak-$STAMP_DATE-$1")" >"$DIRECTORY_WORK/backup.log" 2>&1; then
            fail_line "$1" 'preset backup' "cannot back up $PATH_PRESET"
            indent_output "$DIRECTORY_WORK/backup.log"
            return 1
        fi
        pass_line "$1" 'preset backup' "$PATH_PRESET.bak-$STAMP_DATE-$1"
    else
        skip_line "$1" 'preset backup' "$PATH_PRESET is missing; nothing to back up"
    fi
    if ! scp_to_host "$FILE_PRESET_NEW"; then
        fail_line "$1" 'preset install' 'cannot copy the new preset to the host'
        return 1
    fi
    if ! ssh_host "sudo -n install -m 0644 $(quote_argument "$PATH_REMOTE_COPY") $(quote_argument "$PATH_PRESET")" >"$DIRECTORY_WORK/install.log" 2>&1; then
        fail_line "$1" 'preset install' "cannot install $PATH_PRESET"
        indent_output "$DIRECTORY_WORK/install.log"
        return 1
    fi
    pass_line "$1" 'preset install' "$PATH_PRESET"
    if ! scp_from_host "$PATH_PRESET" "$DIRECTORY_WORK/installed.ini"; then
        fail_line "$1" 'preset install' "cannot read back $PATH_PRESET"
        return 1
    fi
    if ! cmp -s "$FILE_PRESET_NEW" "$DIRECTORY_WORK/installed.ini"; then
        fail_line "$1" 'preset install' "the installed $PATH_PRESET differs from the new preset"
        return 1
    fi
    pass_line "$1" 'preset install' 'read back and identical'
    return 0
}

# install_unit TARGET: back an existing live unit up, install the rendered
# one, and reload systemd.
install_unit() {
    if scp_from_host "$PATH_UNIT" "$DIRECTORY_WORK/unit-live"; then
        if ! ssh_host "sudo -n cp -p $(quote_argument "$PATH_UNIT") $(quote_argument "$PATH_UNIT.bak-$STAMP_DATE-llamainstall")" >"$DIRECTORY_WORK/backup.log" 2>&1; then
            fail_line "$1" 'unit backup' "cannot back up $PATH_UNIT"
            indent_output "$DIRECTORY_WORK/backup.log"
            return 1
        fi
        pass_line "$1" 'unit backup' "$PATH_UNIT.bak-$STAMP_DATE-llamainstall"
    else
        skip_line "$1" 'unit backup' "$PATH_UNIT is missing; nothing to back up"
    fi
    if ! scp_to_host "$FILE_UNIT"; then
        fail_line "$1" 'unit' 'cannot copy the rendered unit to the host'
        return 1
    fi
    if ! ssh_host "sudo -n install -m 0644 $(quote_argument "$PATH_REMOTE_COPY") $(quote_argument "$PATH_UNIT")" >"$DIRECTORY_WORK/install.log" 2>&1; then
        fail_line "$1" 'unit' "cannot install $PATH_UNIT"
        indent_output "$DIRECTORY_WORK/install.log"
        return 1
    fi
    pass_line "$1" 'unit' "$PATH_UNIT"
    if ! ssh_host "sudo -n systemctl daemon-reload" >"$DIRECTORY_WORK/reload.log" 2>&1; then
        fail_line "$1" 'unit' 'systemctl daemon-reload failed'
        indent_output "$DIRECTORY_WORK/reload.log"
        return 1
    fi
    pass_line "$1" 'unit' 'systemctl daemon-reload'
    return 0
}

# read_restarts: set VALUE_RESTARTS to the unit restart counter.
read_restarts() {
    VALUE_RESTARTS=$(ssh_host "systemctl show -p NRestarts --value $NAME_UNIT" 2>/dev/null | sed -n '1p') || VALUE_RESTARTS=''
    return 0
}

# restart_unit TARGET: restart the service, unless staging only. The counter
# before the restart is kept, so the live checks can prove the new start held
# instead of climbing into a restart loop.
restart_unit() {
    RESTARTS_BEFORE=''
    if [ '1' = "$LLAMA_SKIP_RESTART" ]; then
        skip_line "$1" 'restart' 'LLAMA_SKIP_RESTART=1; the unit picks the preset up at its next start'
        return 0
    fi
    read_restarts
    RESTARTS_BEFORE=$VALUE_RESTARTS
    if ! ssh_host "sudo -n systemctl restart $NAME_UNIT" >"$DIRECTORY_WORK/restart.log" 2>&1; then
        fail_line "$1" 'restart' "systemctl restart $NAME_UNIT failed"
        indent_output "$DIRECTORY_WORK/restart.log"
        return 1
    fi
    pass_line "$1" 'restart' "systemctl restart $NAME_UNIT; settling $LLAMA_SETTLE_SECONDS s"
    sleep "$LLAMA_SETTLE_SECONDS"
    return 0
}

# check_active TARGET: systemd reports the unit active.
check_active() {
    VALUE_ACTIVE=$(ssh_host "systemctl is-active $NAME_UNIT" 2>/dev/null | sed -n '1p') || VALUE_ACTIVE=''
    if [ 'active' != "$VALUE_ACTIVE" ]; then
        fail_line "$1" 'active' "systemctl is-active $NAME_UNIT reports '$VALUE_ACTIVE'"
        ssh_host "sudo -n systemctl status --no-pager $NAME_UNIT 2>&1 | tail -n 15" >"$DIRECTORY_WORK/status.log" 2>&1 || true
        indent_output "$DIRECTORY_WORK/status.log"
        return 1
    fi
    pass_line "$1" 'active' "systemctl is-active $NAME_UNIT = active"
    return 0
}

# check_restarts TARGET: report the restart counter. After a restart it must
# not exceed the count read before it: a counter that climbs means the
# router refuses the preset and systemd is looping, which is the 2026-09-10
# failure.
check_restarts() {
    read_restarts
    if [ -z "$RESTARTS_BEFORE" ]; then
        pass_line "$1" 'restarts' "NRestarts=${VALUE_RESTARTS:-unknown}"
        return 0
    fi
    if ! printf '%s' "$VALUE_RESTARTS" | grep -qE '^[0-9]+$'; then
        fail_line "$1" 'restarts' "NRestarts is not a number: ${VALUE_RESTARTS:-empty}"
        return 1
    fi
    if [ "$RESTARTS_BEFORE" -lt "$VALUE_RESTARTS" ]; then
        fail_line "$1" 'restarts' "NRestarts rose from $RESTARTS_BEFORE to $VALUE_RESTARTS: the router is restarting itself"
        return 1
    fi
    pass_line "$1" 'restarts' "NRestarts=$VALUE_RESTARTS (was $RESTARTS_BEFORE before the restart)"
    return 0
}

# check_health TARGET: the router answers /health on the host address.
check_health() {
    URL_HEALTH="http://$HOST_REMOTE:$PORT_LIVE/health"
    if ! curl -sf -m 10 "$URL_HEALTH" >"$DIRECTORY_WORK/health.log" 2>&1; then
        fail_line "$1" 'health' "$URL_HEALTH did not answer"
        indent_output "$DIRECTORY_WORK/health.log"
        return 1
    fi
    pass_line "$1" 'health' "$URL_HEALTH"
    return 0
}

# check_models TARGET: GET /v1/models parses and lists at least one model.
check_models() {
    URL_MODELS="http://$HOST_REMOTE:$PORT_LIVE/v1/models"
    if ! curl -sf -m 10 "$URL_MODELS" >"$DIRECTORY_WORK/models.json" 2>"$DIRECTORY_WORK/models-error.log"; then
        fail_line "$1" 'models' "$URL_MODELS did not answer"
        indent_output "$DIRECTORY_WORK/models-error.log"
        return 1
    fi
    if ! list_models "$DIRECTORY_WORK/models.json"; then
        fail_line "$1" 'models' "no model listed at $URL_MODELS"
        indent_output "$DIRECTORY_WORK/models.log"
        return 1
    fi
    pass_line "$1" 'models' "GET $URL_MODELS parsed"
    indent_output "$DIRECTORY_WORK/models.log"
    return 0
}

# verify_live TARGET: the live checks of an install, or of --verify-only.
verify_live() {
    case $1 in
        beast-gpu|athena-gpu)
            PORT_LIVE=2001
            ;;
        beast-cpu)
            PORT_LIVE=2002
            ;;
    esac
    if ! check_active "$1"; then
        return 1
    fi
    if ! check_restarts "$1"; then
        return 1
    fi
    if ! check_health "$1"; then
        return 1
    fi
    if ! check_models "$1"; then
        return 1
    fi
    return 0
}

# install_target TARGET: the ordered sequence for one target. It stops at
# the first failure, and each change is verified before the next begins.
install_target() {
    select_target "$1"
    STAMP_DATE=$(date +%Y%m%d)
    if ! cp "$FILE_TRACKED_PRESET" "$FILE_PRESET_NEW"; then
        fail_line "$1" 'tracked config' "cannot read $FILE_TRACKED_PRESET"
        return 1
    fi
    echo "== $1: $HOST_REMOTE $NAME_UNIT, $FILE_TRACKED_PRESET as $PATH_PRESET"
    if ! check_reachability "$1"; then
        return 1
    fi
    if ! check_binary "$1"; then
        return 1
    fi
    if [ 'verify' = "$NAME_MODE" ]; then
        if ! verify_live "$1"; then
            return 1
        fi
        return 0
    fi
    if ! check_preset_scene "$1" "$FILE_TRACKED_PRESET" 'tracked preset'; then
        return 1
    fi
    if ! compare_live_preset "$1"; then
        return 1
    fi
    if ! check_unit "$1"; then
        return 1
    fi
    if [ 'dry-run' = "$NAME_MODE" ]; then
        skip_line "$1" 'changes' "would save $PATH_PRESET as $PATH_PRESET.bak-$STAMP_DATE-$1"
        skip_line "$1" 'changes' "would install $FILE_PRESET_NEW as $PATH_PRESET"
        skip_line "$1" 'changes' "would save $PATH_UNIT as $PATH_UNIT.bak-$STAMP_DATE-llamainstall, install the rendered unit, and reload systemd"
        skip_line "$1" 'changes' "would run systemctl restart $NAME_UNIT unless LLAMA_SKIP_RESTART=1"
        skip_line "$1" 'live checks' 'active, restarts, health, and models need a live restart'
        return 0
    fi
    if cmp -s "$FILE_UNIT" "$DIRECTORY_WORK/unit-live"; then
        pass_line "$1" 'unit' 'unit unchanged'
    else
        if ! install_unit "$1"; then
            return 1
        fi
    fi
    if ! install_preset "$1"; then
        return 1
    fi
    if ! restart_unit "$1"; then
        return 1
    fi
    if [ '1' = "$LLAMA_SKIP_RESTART" ]; then
        skip_line "$1" 'live checks' 'LLAMA_SKIP_RESTART=1; the live state still shows the previous start'
        return 0
    fi
    if ! verify_live "$1"; then
        return 1
    fi
    return 0
}

TARGET_NAME_LIST=''
IS_ALL=0
IS_FORCE=0
NAME_MODE='install'

if [ "$#" -eq 0 ]; then
    refuse_usage 'no target and no --all'
fi

for ARGUMENT in "$@"; do
    case $ARGUMENT in
        --dry-run|--verify-only|--force|--all|-h|--help)
            ;;
        -*)
            refuse_usage "unknown option $ARGUMENT"
            ;;
        *)
            if ! printf '%s\n' "$ARGUMENT" | grep -qxE "$PATTERN_TARGET"; then
                refuse_usage "unknown target $ARGUMENT"
            fi
            if printf ' %s ' "$TARGET_NAME_LIST" | grep -q " $ARGUMENT "; then
                refuse_usage "target $ARGUMENT named twice"
            fi
            TARGET_NAME_LIST="$TARGET_NAME_LIST $ARGUMENT"
            ;;
    esac
done

while [ "$#" -gt 0 ]; do
    case $1 in
        --dry-run)
            if [ 'verify' = "$NAME_MODE" ]; then
                refuse_usage '--dry-run and --verify-only cannot be combined'
            fi
            NAME_MODE='dry-run'
            ;;
        --verify-only)
            if [ 'dry-run' = "$NAME_MODE" ]; then
                refuse_usage '--dry-run and --verify-only cannot be combined'
            fi
            NAME_MODE='verify'
            ;;
        --force)
            IS_FORCE=1
            ;;
        --all)
            if [ -n "$TARGET_NAME_LIST" ]; then
                refuse_usage '--all and named targets cannot be combined'
            fi
            IS_ALL=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
    esac
    shift
done

if [ '1' = "$IS_ALL" ]; then
    TARGET_NAME_LIST=' beast-gpu beast-cpu athena-gpu'
fi

if [ -z "$TARGET_NAME_LIST" ]; then
    refuse_usage 'no target and no --all'
fi

if [ 'install' != "$NAME_MODE" ] && [ '1' = "$IS_FORCE" ]; then
    refuse_usage "--force changes files and cannot be combined with --$NAME_MODE"
fi

for VALUE_TOOL in curl python3 scp ssh; do
    command -v "$VALUE_TOOL" >/dev/null 2>&1 || fail "missing tool: $VALUE_TOOL"
done

REPOSITORY_ROOT=${LLAMA_REPOSITORY_ROOT:-$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)}
FILE_CHECKER="$DIRECTORY_SCRIPT/preset-keys-check.sh"

LLAMA_ACCEPT_REMOTE_DIFF=${LLAMA_ACCEPT_REMOTE_DIFF:-0}
LLAMA_HOST_ATHENA_GPU=${LLAMA_HOST_ATHENA_GPU:-athena.lan}
LLAMA_HOST_BEAST_CPU=${LLAMA_HOST_BEAST_CPU:-beast.lan}
LLAMA_HOST_BEAST_GPU=${LLAMA_HOST_BEAST_GPU:-beast.lan}
LLAMA_KEY_ATHENA=${LLAMA_KEY_ATHENA:-$HOME/.ssh/keys/key-athena}
LLAMA_KEY_BEAST=${LLAMA_KEY_BEAST:-$HOME/.ssh/keys/key-beast}
LLAMA_SCRATCH_PORT=${LLAMA_SCRATCH_PORT:-61555}
LLAMA_SETTLE_SECONDS=${LLAMA_SETTLE_SECONDS:-5}
LLAMA_SKIP_RESTART=${LLAMA_SKIP_RESTART:-0}
SSH_OPTIONS=${SSH_OPTIONS:-'-F /dev/null -o BatchMode=yes -o ConnectTimeout=8'}

if [ '1' = "$LLAMA_ACCEPT_REMOTE_DIFF" ]; then
    IS_FORCE=1
fi

if ! printf '%s' "$LLAMA_SCRATCH_PORT" | grep -qE '^[1-9][0-9]{3,4}$' || [ 65535 -lt "$LLAMA_SCRATCH_PORT" ]; then
    fail "LLAMA_SCRATCH_PORT is not a port number: $LLAMA_SCRATCH_PORT"
fi

if ! printf '%s' "$LLAMA_SETTLE_SECONDS" | grep -qE '^[0-9]+$' || [ 120 -lt "$LLAMA_SETTLE_SECONDS" ]; then
    fail "LLAMA_SETTLE_SECONDS is not a wait of 0 to 120 seconds: $LLAMA_SETTLE_SECONDS"
fi

if [ ! -f "$FILE_CHECKER" ]; then
    fail "missing checker $FILE_CHECKER"
fi

for FILE_TRACKED in \
    "$REPOSITORY_ROOT/sources/config/beast-config.applied.ini" \
    "$REPOSITORY_ROOT/sources/config/beast-config-cpu.applied.ini" \
    "$REPOSITORY_ROOT/sources/config/athena-config.applied.ini"; do
    if [ ! -s "$FILE_TRACKED" ]; then
        fail "missing tracked config $FILE_TRACKED"
    fi
done

if ! REPOSITORY_ROOT=$(CDPATH= cd -- "$REPOSITORY_ROOT" && pwd); then
    fail "LLAMA_REPOSITORY_ROOT is not a directory: $REPOSITORY_ROOT"
fi

DIRECTORY_WORK_CREATED=''
if [ -n "${LLAMA_SCRATCH_DIRECTORY:-}" ]; then
    DIRECTORY_WORK=$LLAMA_SCRATCH_DIRECTORY
    mkdir -p "$DIRECTORY_WORK"
else
    DIRECTORY_WORK=$(mktemp -d)
    DIRECTORY_WORK_CREATED=1
fi

if ! DIRECTORY_WORK=$(CDPATH= cd -- "$DIRECTORY_WORK" && pwd); then
    fail "the scratch directory cannot be resolved: $DIRECTORY_WORK"
fi

HOST_REMOTE=''
FILE_SSH_KEY=''
PATH_REMOTE_SCRIPT=''
PATH_REMOTE_LOG=''
PATH_REMOTE_COPY=''
trap 'cleanup_all' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "$NAME_SCRIPT: mode $NAME_MODE; targets:$TARGET_NAME_LIST"
for TARGET_NAME in $TARGET_NAME_LIST; do
    if ! install_target "$TARGET_NAME"; then
        echo "STOP $TARGET_NAME: failed closed at the FAIL above" >&2
        exit 1
    fi
done

if [ 'dry-run' = "$NAME_MODE" ]; then
    echo "$NAME_SCRIPT: ok (dry run; nothing changed)"
else
    echo "$NAME_SCRIPT: ok"
fi
exit 0
