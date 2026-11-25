#!/bin/sh
#
# backup-models.sh: back up a host's HuggingFace model cache to /backups.
#
# The convention (documents/12-model-retention.md, "Conventions", owner
# 2026-09-03) is:
#   - every model downloaded on a host is archived to /backups/huggingface/
#     on that host (large spinning storage);
#   - the live HF_HUB_CACHE keeps only models that host actually runs, so the
#     fast disk stays small;
#   - a model dropped from the live cache stays in /backups and can be
#     restored instead of downloaded again.
#
# The copy is additive: rsync never deletes from the archive, so a model
# removed from the live cache remains in /backups. That is the point of the
# archive and the reason --delete is not used.
#
# Usage: sh scripts/backup-models.sh [HOST] [--dry-run]
#   HOST      beast | athena | minerva | all (default: all)
#   --dry-run show what would be copied; changes nothing
#
# Exit status: 0 when every target backed up (or would, in a dry run),
# 1 when any target failed.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

PATH_SSH_KEYS="$HOME/.ssh/keys"
PATH_REMOTE_ARCHIVE=/backups/huggingface
SSH_OPTIONS="-F /dev/null -o BatchMode=yes -o ConnectTimeout=8"

HOST_TARGET=${1:-all}
MODE=${2:-run}

case $MODE in
    run | --dry-run) ;;
    *)
        echo "backup-models: unknown mode: $MODE (use --dry-run)" >&2
        exit 2
        ;;
esac

# host_for_target TARGET: print "host key archive_host" for a target name.
# The archive host is where the copy lands. It is the same host for the
# servers, which each have their own /backups volume. The laptop has no
# /backups volume, so its cache is archived on beast while the two are on the
# same subnet; the archive host is empty when the target archives locally.
host_for_target() {
    case $1 in
        beast) echo "beast.lan key-beast" ;;
        athena) echo "athena.lan key-athena" ;;
        minerva) echo "minerva.lan key-athena beast.lan" ;;
        *)
            echo "backup-models: unknown target: $1" >&2
            return 1
            ;;
    esac
}

# backup_host TARGET: copy that host's live cache to its archive.
backup_host() {
    TARGET=$1
    set -- $(host_for_target "$TARGET")
    HOST_REMOTE=$1
    NAME_KEY=$2
    FILE_KEY="$PATH_SSH_KEYS/$NAME_KEY"

    if [ ! -f "$FILE_KEY" ]; then
        echo "FAIL $TARGET: missing ssh key $FILE_KEY" >&2
        return 1
    fi

    if [ "$MODE" = "--dry-run" ]; then
        if ! ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
            "test -d '$PATH_REMOTE_ARCHIVE'" >/dev/null 2>&1; then
            echo "SKIP $TARGET: no $PATH_REMOTE_ARCHIVE on $HOST_REMOTE; no separate archive volume"
            return 0
        fi
        echo "== $TARGET ($HOST_REMOTE): would copy the live cache to $PATH_REMOTE_ARCHIVE"
        ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
            "rsync -a --dry-run --itemize-changes \
                \"\$HOME/.cache/huggingface/hub/\" \"$PATH_REMOTE_ARCHIVE/hub/\" \
                2>/dev/null | grep -c '^[<>ch]' || true" 2>/dev/null |
            while read -r COUNT; do
                echo "   $COUNT item(s) would change"
            done
        return 0
    fi

    # The archive needs a separate volume to be worth having. A host without
    # one (the laptop has a single 935 GB volume) cannot archive locally, and
    # that is reported as a skip rather than a copy failure.
    if ! ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
        "test -d '$PATH_REMOTE_ARCHIVE'" >/dev/null 2>&1; then
        echo "SKIP $TARGET: no $PATH_REMOTE_ARCHIVE on $HOST_REMOTE; no separate archive volume" >&2
        return 0
    fi

    echo "== $TARGET ($HOST_REMOTE): copying the live cache to $PATH_REMOTE_ARCHIVE"
    if ! ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
        "set -e
         mkdir -p '$PATH_REMOTE_ARCHIVE/hub'
         rsync -a \"\$HOME/.cache/huggingface/hub/\" '$PATH_REMOTE_ARCHIVE/hub/'" \
        >/dev/null 2>&1; then
        echo "FAIL $TARGET: rsync to $PATH_REMOTE_ARCHIVE failed" >&2
        return 1
    fi

    # Report what is now in the archive, so a silent empty copy is visible.
    ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
        "printf '   archive: '; ls '$PATH_REMOTE_ARCHIVE/hub' 2>/dev/null | grep -c '^models--' | tr -d '\n'; printf ' model(s), '; du -sh '$PATH_REMOTE_ARCHIVE/hub' 2>/dev/null | cut -f1" \
        2>/dev/null || true
    echo "PASS $TARGET: cache backed up to $PATH_REMOTE_ARCHIVE"
    return 0
}

# backup_host_remote TARGET HOST_ARCHIVE: archive a host's cache on another
# host over the LAN. Used when the source has no archive volume of its own
# (the laptop) and the archive host is reachable on the same subnet.
backup_host_remote() {
    TARGET=$1
    HOST_ARCHIVE=$2
    set -- $(host_for_target "$TARGET")
    HOST_REMOTE=$1
    NAME_KEY=$2
    FILE_KEY="$PATH_SSH_KEYS/$NAME_KEY"

    # The archive host is reached from the source host, so the source must
    # carry its own key for it. minerva has key-beast for this.
    if ! ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
        "ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -i ~/.ssh/keys/key-beast preston@$HOST_ARCHIVE 'true'" \
        >/dev/null 2>&1; then
        echo "SKIP $TARGET: $HOST_ARCHIVE is not reachable from $HOST_REMOTE; nothing copied" >&2
        return 0
    fi

    if [ "$MODE" = "--dry-run" ]; then
        echo "== $TARGET ($HOST_REMOTE): would copy the live cache to $HOST_ARCHIVE:$PATH_REMOTE_ARCHIVE"
        ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
            "rsync -a --dry-run --itemize-changes \
                \"\$HOME/.cache/huggingface/hub/\" \
                'preston@$HOST_ARCHIVE:$PATH_REMOTE_ARCHIVE/hub/' \
                2>/dev/null | grep -c '^[<>ch]' || true" 2>/dev/null |
            while read -r COUNT; do
                echo "   $COUNT item(s) would change"
            done
        return 0
    fi

    echo "== $TARGET ($HOST_REMOTE): copying the live cache to $HOST_ARCHIVE:$PATH_REMOTE_ARCHIVE"
    # The archive directory is created on the archive host, not on the source;
    # the source has no /backups volume of its own.
    if ! ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
        "set -e
         ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -i ~/.ssh/keys/key-beast preston@$HOST_ARCHIVE 'mkdir -p $PATH_REMOTE_ARCHIVE/hub'
         rsync -a -e 'ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -i ~/.ssh/keys/key-beast' \
             \"\$HOME/.cache/huggingface/hub/\" \
             'preston@$HOST_ARCHIVE:$PATH_REMOTE_ARCHIVE/hub/'" \
        >/dev/null 2>&1; then
        echo "FAIL $TARGET: rsync to $HOST_ARCHIVE:$PATH_REMOTE_ARCHIVE failed" >&2
        return 1
    fi

    ssh $SSH_OPTIONS -i "$FILE_KEY" "preston@$HOST_REMOTE" \
        "ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -i ~/.ssh/keys/key-beast preston@$HOST_ARCHIVE \
            \"printf '   archive: '; ls '$PATH_REMOTE_ARCHIVE/hub' 2>/dev/null | grep -c '^models--' | tr -d '\n'; printf ' model(s), '; du -sh '$PATH_REMOTE_ARCHIVE/hub' 2>/dev/null | cut -f1\"" \
        2>/dev/null || true
    echo "PASS $TARGET: cache backed up to $HOST_ARCHIVE:$PATH_REMOTE_ARCHIVE"
    return 0
}

case $HOST_TARGET in
    all) TARGETS="beast athena minerva" ;;
    *) TARGETS=$HOST_TARGET ;;
esac

STATUS=0
for TARGET in $TARGETS; do
    # A target with an archive host archives on that host; the rest archive
    # locally. host_for_target prints a third field only for the laptop.
    set -- $(host_for_target "$TARGET")
    HOST_ARCHIVE=${3:-}
    if [ -n "$HOST_ARCHIVE" ]; then
        backup_host_remote "$TARGET" "$HOST_ARCHIVE" || STATUS=1
    else
        backup_host "$TARGET" || STATUS=1
    fi
done

exit $STATUS
