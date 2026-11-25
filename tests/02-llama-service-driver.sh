#!/bin/sh
#
# Test for scripts/llama-service-install.sh, the Makefile llama-service driver.
#
# Portable: no network, no root, and nothing outside a temporary directory.
# HOME and XDG are sandboxed, and ssh, scp, and curl are replaced by shims on
# PATH, so no call can reach a real host.
#
# The fake-host design is deliberately plain. Every shim appends its name and
# arguments to one log, a line per call, so a case can prove which commands
# ran:
#
#   - fake ssh answers a fixed set of read-only commands (reachability,
#     command -v, --version, preset-keys-check.sh, the scratch log poll, the
#     scratch model list) and exits 255 for everything else. That exit is also
#     the unreachable host, so a switch file that makes it fail every call
#     models a host the driver cannot reach.
#   - fake scp copies a path to the fake host directory or back. OpenSSH scp
#     spawns its own ssh, so the driver's scp cannot reach the fake ssh; the
#     test passes the -S option, which a real scp uses for its remote shell,
#     through SSH_OPTIONS and the shim reads it as "copy locally".
#   - fake curl answers /health and /v1/models for athena.lan:2001 only.
#
# The cases: the driver parses; no argument and an unknown option are
# refused; an unreachable host fails closed; a full dry run for athena-gpu
# passes and changes nothing; a changed live preset is reported and refused;
# --verify-only checks the live state without changing it; an inactive unit
# fails --verify-only; the defaults are the documented ones; and the
# Makefile has the three llama-service rules.
set -eu

. "$(dirname -- "$0")/lib/test_helpers.sh"

NAME_TEST='02-llama-service-driver'

skip_unless_tool python3
skip_unless_tool make

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
FILE_DRIVER="$REPOSITORY_ROOT/scripts/llama-service-install.sh"
FILE_MAKEFILE="$REPOSITORY_ROOT/Makefile"

DIRECTORY_TEMP=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEMP"' EXIT HUP INT TERM

DIRECTORY_BIN="$DIRECTORY_TEMP/bin"
DIRECTORY_HOME="$DIRECTORY_TEMP/home"
DIRECTORY_HOST="$DIRECTORY_TEMP/host"
FILE_CALLS="$DIRECTORY_TEMP/calls.log"
FILE_HOST_STATUS="$DIRECTORY_TEMP/host-status"

mkdir -p "$DIRECTORY_BIN" "$DIRECTORY_HOME" "$DIRECTORY_HOST/usr/local/etc" "$DIRECTORY_HOST/etc/systemd/system"

# The shims expand these values when the test writes them, so a bare name in
# a shim reads nothing at run time; export them for the child processes.
FILE_CALLS=$FILE_CALLS
FILE_HOST_STATUS=$FILE_HOST_STATUS
DIRECTORY_HOST=$DIRECTORY_HOST
export FILE_CALLS FILE_HOST_STATUS DIRECTORY_HOST

fail() {
    echo "$NAME_TEST: $1" >&2
    exit 1
}

# The fake ssh. Every option shape the driver uses is skipped by arity, so
# the command is whatever follows "-i <key> <host>".
cat >"$DIRECTORY_BIN/fake-ssh" <<SHIM
#!/bin/sh
printf 'ssh %s\n' "\$*" >>"$FILE_CALLS"
if [ -f "$FILE_HOST_STATUS" ]; then
    echo 'ssh: connect to host athena.lan port 22: Connection refused' >&2
    exit 255
fi
COMMAND=''
HOST_SEEN=''
OPTION=''
for ARGUMENT in "\$@"; do
    if [ -n "\$OPTION" ]; then
        OPTION=''
        continue
    fi
    case \$ARGUMENT in
        -F|-i|-o|-S)
            OPTION=\$ARGUMENT
            ;;
        -*)
            ;;
        *)
            if [ -z "\$HOST_SEEN" ]; then
                HOST_SEEN=1
                continue
            fi
            if [ -z "\$COMMAND" ]; then
                COMMAND=\$ARGUMENT
            else
                COMMAND="\$COMMAND \$ARGUMENT"
            fi
            ;;
    esac
done
case \$COMMAND in
    'command -v llama-server')
        echo '/usr/local/bin/llama-server'
        exit 0
        ;;
    'sudo -n curl -sf'*)
        echo '{"object":"list","data":[{"id":"fake/model:Q8_0","aliases":["fake"],"status":{"value":"unloaded"}}]}'
        exit 0
        ;;
    'sudo -n '*|'sudo '*|install\ *|cp\ *|rm\ *|mkdir\ *|chmod\ *|chown\ *|pkill\ *|tail\ *|cat\ *|test\ *|systemctl\ show\ *)
        exit 0
        ;;
    *'--version 2>&1 | head -n 1')
        echo 'version: 9999 (fake build)'
        exit 0
        ;;
    *'preset-keys-check.sh'*)
        echo 'preset-keys-check: fake run'
        echo '  ok   load-mode = mmap'
        echo '  ok   ctx-size = 8192'
        echo '  ok   fit = on'
        echo 'preset-keys-check: review any BAD keys before restarting the service'
        exit 0
        ;;
    *"grep -h -m 1 listening on "*)
        echo 'srv    main: server is listening on 127.0.0.1:61555'
        exit 0
        ;;
    *'curl -sf -m 5 http://127.0.0.1:61555/health'*)
        echo '{"status":"ok"}'
        exit 0
        ;;
    *'curl -sf -m 10 http://127.0.0.1:61555/v1/models'*)
        echo '{"object":"list","data":[{"id":"fake/model:Q8_0","aliases":["fake"],"status":{"value":"unloaded"}}]}'
        exit 0
        ;;
    *"grep -E -m 8 "*)
        echo 'srv    build: 9999 (fake build)'
        exit 0
        ;;
    'systemctl is-active llama.service'|'systemctl is-active llama-cpu.service')
        echo active
        exit 0
        ;;
    'systemctl show -p NRestarts --value llama.service'|'systemctl show -p NRestarts --value llama-cpu.service')
        echo 0
        exit 0
        ;;
    true)
        exit 0
        ;;
    *)
        echo "fake ssh: refusing command: \$COMMAND" >&2
        exit 255
        ;;
esac
SHIM

# The fake scp. -S selects the local copy, because a real scp would spawn a
# remote shell the fake host does not have.
cat >"$DIRECTORY_BIN/fake-scp" <<SHIM
#!/bin/sh
printf 'scp %s\n' "\$*" >>"$FILE_CALLS"
SOURCE=''
DESTINATION=''
OPTION=''
for ARGUMENT in "\$@"; do
    if [ -n "\$OPTION" ]; then
        OPTION=''
        continue
    fi
    case \$ARGUMENT in
        -F|-i|-o|-S)
            OPTION=\$ARGUMENT
            ;;
        -O)
            ;;
        -*)
            ;;
        *)
            if [ -z "\$SOURCE" ]; then
                SOURCE=\$ARGUMENT
            else
                DESTINATION=\$ARGUMENT
            fi
            ;;
    esac
done
if [ -z "\$DESTINATION" ]; then
    echo 'fake scp: no destination' >&2
    exit 255
fi
REMOTE_PATH=\$(printf '%s\n' "\$DESTINATION" | sed 's/^athena\.lan://')
if [ "\$REMOTE_PATH" != "\$DESTINATION" ]; then
    HOST_PATH=\$(printf '%s/%s\n' "$DIRECTORY_HOST" "\$REMOTE_PATH")
    mkdir -p "\$(dirname -- "\$HOST_PATH")" || exit 255
    cp "\$SOURCE" "\$HOST_PATH" || exit 255
    exit 0
fi
SOURCE_PATH=\$(printf '%s\n' "\$SOURCE" | sed 's/^athena\.lan://')
cp "\$(printf '%s/%s\n' "$DIRECTORY_HOST" "\$SOURCE_PATH")" "\$DESTINATION" || exit 255
exit 0
SHIM

cat >"$DIRECTORY_BIN/fake-curl" <<SHIM
#!/bin/sh
printf 'curl %s\n' "\$*" >>"$FILE_CALLS"
URL=''
for ARGUMENT in "\$@"; do
    case \$ARGUMENT in
        http://*)
            URL=\$ARGUMENT
            ;;
    esac
done
case \$URL in
    http://athena.lan:2001/health)
        echo '{"status":"ok"}'
        exit 0
        ;;
    http://athena.lan:2001/v1/models)
        echo '{"object":"list","data":[{"id":"fake/live-model:Q8_0","aliases":["livel"]},{"id":"fake/other:Q4_K_M","aliases":[]}]}'
        exit 0
        ;;
    *)
        echo "fake curl: no route to \$URL" >&2
        exit 7
        ;;
esac
SHIM

chmod +x "$DIRECTORY_BIN/fake-ssh" "$DIRECTORY_BIN/fake-scp" "$DIRECTORY_BIN/fake-curl"
ln -s fake-ssh "$DIRECTORY_BIN/ssh"
ln -s fake-scp "$DIRECTORY_BIN/scp"
ln -s fake-curl "$DIRECTORY_BIN/curl"

# The fake host state the shims read back: the live preset and unit.
cp "$REPOSITORY_ROOT/sources/config/athena-config.applied.ini" "$DIRECTORY_HOST/usr/local/etc/config.ini"
cat >"$DIRECTORY_HOST/etc/systemd/system/llama.service" <<'UNIT'
[Unit]
Description=Llama.cpp Multi-Model Subnet Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --models-preset /usr/local/etc/config.ini --host 0.0.0.0 --port 2001 --tools all
UNIT

# run_driver HOME_SANDBOX ARGUMENT...: run the driver against the shims.
run_driver() {
    DIRECTORY_SANDBOX_HOME=$1
    shift
    PATH="$DIRECTORY_BIN:$PATH" \
    HOME="$DIRECTORY_SANDBOX_HOME" \
    XDG_CACHE_HOME="$DIRECTORY_SANDBOX_HOME/.cache" \
    XDG_CONFIG_HOME="$DIRECTORY_SANDBOX_HOME/.config" \
    LLAMA_HOST_ATHENA_GPU=athena.lan \
    SSH_OPTIONS="-S $DIRECTORY_BIN/fake-scp -F /dev/null -o BatchMode=yes -o ConnectTimeout=2" \
    LLAMA_KEY_ATHENA="$DIRECTORY_SANDBOX_HOME/.ssh/keys/key-athena" \
    LLAMA_SKIP_RESTART=1 \
    LLAMA_SETTLE_SECONDS=0 \
    LLAMA_SCRATCH_PORT=61555 \
    sh "$FILE_DRIVER" "$@"
}

# 1. The driver parses.
sh -n "$FILE_DRIVER" || fail 'sh -n rejected the driver'

# 2. No argument prints the usage on stderr and exits nonzero.
STATUS_NO_ARGUMENT=0
sh "$FILE_DRIVER" >"$DIRECTORY_TEMP/no-argument.out" 2>"$DIRECTORY_TEMP/no-argument.err" || STATUS_NO_ARGUMENT=$?
[ '0' != "$STATUS_NO_ARGUMENT" ] || fail 'no argument exited 0'
grep -q 'Usage:' "$DIRECTORY_TEMP/no-argument.err" || fail 'no argument printed no usage on stderr'
grep -q 'no target' "$DIRECTORY_TEMP/no-argument.err" || fail 'no argument named no reason'

# 3. An unknown option is refused with the usage, and the Makefile passes it
# through to the driver rather than hiding it.
STATUS_BOGUS=0
sh "$FILE_DRIVER" --dry-run athena-gpu --bogus-flag >"$DIRECTORY_TEMP/bogus.out" 2>&1 || STATUS_BOGUS=$?
[ '0' != "$STATUS_BOGUS" ] || fail 'the driver accepted --bogus-flag'
grep -q 'unknown option --bogus-flag' "$DIRECTORY_TEMP/bogus.out" || fail 'the driver named no unknown option'
grep -q 'Usage:' "$DIRECTORY_TEMP/bogus.out" || fail 'the driver printed no usage for --bogus-flag'
STATUS_MAKE=0
make -s -C "$REPOSITORY_ROOT" llama-service TARGETS=--bogus-flag >"$DIRECTORY_TEMP/make-bogus.out" 2>&1 || STATUS_MAKE=$?
[ '0' != "$STATUS_MAKE" ] || fail 'make llama-service accepted --bogus-flag'
grep -q 'unknown option --bogus-flag' "$DIRECTORY_TEMP/make-bogus.out" || fail 'make llama-service lost the refusal'

# 4. --dry-run fails closed when the host is unreachable.
: >"$FILE_CALLS"
: >"$FILE_HOST_STATUS"
STATUS_UNREACHABLE=0
run_driver "$DIRECTORY_HOME" --dry-run athena-gpu >"$DIRECTORY_TEMP/unreachable.out" 2>&1 || STATUS_UNREACHABLE=$?
[ '0' != "$STATUS_UNREACHABLE" ] || fail 'an unreachable host exited 0'
grep -q 'FAIL athena-gpu: reachability' "$DIRECTORY_TEMP/unreachable.out" || fail 'an unreachable host raised no reachability FAIL'
grep -q 'STOP athena-gpu' "$DIRECTORY_TEMP/unreachable.out" || fail 'an unreachable host did not stop the target'
if grep -vE '^ssh .* athena\.lan true$' "$FILE_CALLS" | grep -q .; then
    fail 'an unreachable host still ran a change'
fi
rm -f "$FILE_HOST_STATUS"

# 5. A full dry run for athena-gpu passes every read-only check.
: >"$FILE_CALLS"
STATUS_DRY_RUN=0
run_driver "$DIRECTORY_HOME" --dry-run athena-gpu >"$DIRECTORY_TEMP/dry-run.out" 2>&1 || STATUS_DRY_RUN=$?
if [ '0' != "$STATUS_DRY_RUN" ]; then
    cat "$DIRECTORY_TEMP/dry-run.out" >&2
    fail 'the dry run for athena-gpu failed'
fi
for EXPECTED in \
    'PASS athena-gpu: reachability' \
    'PASS athena-gpu: binary: /usr/local/bin/llama-server (version: 9999' \
    'PASS athena-gpu: keys tracked preset: 3 key(s) accepted, no BAD key' \
    'PASS athena-gpu: dry run tracked preset' \
    'PASS athena-gpu: models tracked preset: model count: 1' \
    'PASS athena-gpu: live preset diff' \
    'PASS athena-gpu: unit' \
    'SKIP athena-gpu: changes' \
    'ok (dry run; nothing changed)'; do
    grep -qF -- "$EXPECTED" "$DIRECTORY_TEMP/dry-run.out" || fail "the dry run printed no: $EXPECTED"
done
if grep -q 'FAIL ' "$DIRECTORY_TEMP/dry-run.out"; then
    fail 'the dry run printed a FAIL'
fi

# The dry run changed nothing: the host preset is untouched, no backup was
# written, the sandbox HOME is empty, and no change command reached the host.
cmp -s "$DIRECTORY_HOST/usr/local/etc/config.ini" "$REPOSITORY_ROOT/sources/config/athena-config.applied.ini" \
    || fail 'the dry run changed the host preset'
if ls "$DIRECTORY_HOST/usr/local/etc" | grep -q '\.bak-'; then
    fail 'the dry run wrote a host backup'
fi
if [ -n "$(ls -A "$DIRECTORY_HOST/etc/systemd")" ] && ls "$DIRECTORY_HOST/etc/systemd" | grep -q '\.bak-'; then
    fail 'the dry run wrote a host unit backup'
fi
if [ -n "$(ls -A "$DIRECTORY_HOME")" ]; then
    fail 'the dry run wrote into the sandbox HOME'
fi
# Only reads may reach the host: every ssh line must carry a read command,
# plus the scratch log removal that starts a dry run.
sed -n 's/.* athena\.lan //p' "$FILE_CALLS" >"$DIRECTORY_TEMP/ssh-commands.log"
if grep -vE "^(true|command -v llama-server|/usr/local/bin/llama-server --version|sh '[^']*preset-keys-check\.sh'|sudo -n (rm -f|pkill|curl -sf|grep)|nohup sudo -n /usr/local/bin/llama-server )" "$DIRECTORY_TEMP/ssh-commands.log" | grep -q .; then
    cat "$DIRECTORY_TEMP/ssh-commands.log" >&2
    fail 'the dry run sent a command that is not a read'
fi

# 6. --verify-only checks the live state and changes nothing.
: >"$FILE_CALLS"
STATUS_VERIFY=0
run_driver "$DIRECTORY_HOME" --verify-only athena-gpu >"$DIRECTORY_TEMP/verify.out" 2>&1 || STATUS_VERIFY=$?
if [ '0' != "$STATUS_VERIFY" ]; then
    cat "$DIRECTORY_TEMP/verify.out" >&2
    fail '--verify-only failed against the fake live service'
fi
for EXPECTED in \
    'PASS athena-gpu: active: systemctl is-active llama.service = active' \
    'PASS athena-gpu: restarts: NRestarts=' \
    'PASS athena-gpu: health: http://athena.lan:2001/health' \
    'PASS athena-gpu: models: GET http://athena.lan:2001/v1/models parsed' \
    'model count: 2'; do
    grep -qF -- "$EXPECTED" "$DIRECTORY_TEMP/verify.out" || fail "--verify-only printed no: $EXPECTED"
done
grep -q 'fake/live-model:Q8_0 \[livel\]' "$DIRECTORY_TEMP/verify.out" || fail '--verify-only printed no alias'
if grep -qE '^(scp )' "$FILE_CALLS" || grep -q 'sudo -n' "$FILE_CALLS"; then
    fail '--verify-only ran a change'
fi

# 8. An inactive unit fails --verify-only.
cat >"$DIRECTORY_BIN/fake-ssh-inactive" <<SHIM
#!/bin/sh
# The fake host again, with the unit reported inactive.
printf 'ssh %s\n' "\$*" >>"$FILE_CALLS"
COMMAND=''
OPTION=''
HOST_SEEN=''
for ARGUMENT in "\$@"; do
    if [ -n "\$OPTION" ]; then
        OPTION=''
        continue
    fi
    case \$ARGUMENT in
        -F|-i|-o|-S)
            OPTION=\$ARGUMENT
            ;;
        -*)
            ;;
        *)
            if [ -z "\$HOST_SEEN" ]; then
                HOST_SEEN=1
                continue
            fi
            if [ -z "\$COMMAND" ]; then
                COMMAND=\$ARGUMENT
            else
                COMMAND="\$COMMAND \$ARGUMENT"
            fi
            ;;
    esac
done
case \$COMMAND in
    'command -v llama-server')
        echo '/usr/local/bin/llama-server'
        ;;
    *'--version 2>&1 | head -n 1')
        echo 'version: 9999 (fake build)'
        ;;
    'systemctl is-active '*)
        echo inactive
        exit 3
        ;;
esac
exit 0
SHIM
chmod +x "$DIRECTORY_BIN/fake-ssh-inactive"
STATUS_INACTIVE=0
PATH="$DIRECTORY_BIN:$PATH" \
HOME="$DIRECTORY_HOME" \
LLAMA_HOST_ATHENA_GPU=athena.lan \
SSH_OPTIONS="-S $DIRECTORY_BIN/fake-scp -F /dev/null" \
LLAMA_KEY_ATHENA="$DIRECTORY_HOME/.ssh/keys/key-athena" \
sh -c "ln -sf fake-ssh-inactive '$DIRECTORY_BIN/ssh'; sh '$FILE_DRIVER' --verify-only athena-gpu" >"$DIRECTORY_TEMP/inactive.out" 2>&1 || STATUS_INACTIVE=$?
ln -sf fake-ssh "$DIRECTORY_BIN/ssh"
[ '0' != "$STATUS_INACTIVE" ] || fail 'an inactive unit exited 0'
grep -q 'FAIL athena-gpu: active' "$DIRECTORY_TEMP/inactive.out" || fail 'an inactive unit raised no active FAIL'

# 9. The defaults are the documented ones, keyed to $HOME, and the driver
# carries no absolute home path.
grep -q 'LLAMA_KEY_BEAST=${LLAMA_KEY_BEAST:-$HOME/.ssh/keys/key-beast}' "$FILE_DRIVER" \
    || fail 'the beast key default is not $HOME-relative'
grep -q 'LLAMA_KEY_ATHENA=${LLAMA_KEY_ATHENA:-$HOME/.ssh/keys/key-athena}' "$FILE_DRIVER" \
    || fail 'the athena key default is not $HOME-relative'
grep -q "SSH_OPTIONS=\${SSH_OPTIONS:-'-F /dev/null" "$FILE_DRIVER" || fail 'the SSH_OPTIONS default lacks -F /dev/null'
grep -q 'LLAMA_HOST_BEAST_GPU=${LLAMA_HOST_BEAST_GPU:-beast.lan}' "$FILE_DRIVER" || fail 'the beast-gpu host default is not beast.lan'
grep -q 'LLAMA_HOST_BEAST_CPU=${LLAMA_HOST_BEAST_CPU:-beast.lan}' "$FILE_DRIVER" || fail 'the beast-cpu host default is not beast.lan'
grep -q 'LLAMA_HOST_ATHENA_GPU=${LLAMA_HOST_ATHENA_GPU:-athena.lan}' "$FILE_DRIVER" || fail 'the athena-gpu host default is not athena.lan'
grep -q 'LLAMA_SCRATCH_PORT=${LLAMA_SCRATCH_PORT:-61555}' "$FILE_DRIVER" || fail 'the scratch port default is not 61555'
if grep -qE '/(home|root)/[a-z]+' "$FILE_DRIVER"; then
    fail 'the driver carries an absolute home path'
fi

# 10. The Makefile routes the three rules through the driver, and TARGETS
# narrows the set.
grep -q '^llama-service:' "$FILE_MAKEFILE" || fail 'the Makefile has no llama-service rule'
grep -q '^llama-service-dry-run:' "$FILE_MAKEFILE" || fail 'the Makefile has no llama-service-dry-run rule'
grep -q '^llama-service-verify:' "$FILE_MAKEFILE" || fail 'the Makefile has no llama-service-verify rule'
make -n -C "$REPOSITORY_ROOT" llama-service | grep -q 'llama-service-install.sh --all' || fail 'make llama-service does not default to --all'
make -n -C "$REPOSITORY_ROOT" llama-service TARGETS='beast-gpu athena-gpu' | grep -q 'llama-service-install.sh beast-gpu athena-gpu$' \
    || fail 'make llama-service does not pass TARGETS through'
make -n -C "$REPOSITORY_ROOT" llama-service-dry-run | grep -q 'llama-service-install.sh --all --dry-run' || fail 'make llama-service-dry-run does not default to --all --dry-run'
make -n -C "$REPOSITORY_ROOT" llama-service-verify TARGETS=athena-gpu | grep -q 'llama-service-install.sh athena-gpu --verify-only' \
    || fail 'make llama-service-verify does not pass TARGETS through'

# 11. The driver installs the current applied archives, never the stale
# reference copies under sources/models/.
for FILE_APPLIED in \
    'sources/config/beast-config.applied.ini' \
    'sources/config/beast-config-cpu.applied.ini' \
    'sources/config/athena-config.applied.ini'; do
    grep -qF -- "$FILE_APPLIED" "$FILE_DRIVER" || fail "the driver does not name $FILE_APPLIED"
done
if grep -qE 'sources/models/config-(beast|athena)\.ini' "$FILE_DRIVER"; then
    fail 'the driver installs a stale sources/models/config-*.ini'
fi

pass_test "$NAME_TEST"
