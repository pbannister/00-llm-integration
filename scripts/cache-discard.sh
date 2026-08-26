#!/bin/sh
#
# Discard the model files marked discard-candidate in
# documents/12-model-retention.md (owner-approved 2026-08-26).
#
# Usage: sh scripts/cache-discard.sh <athena|beast> [--dry-run]
#
# Deletes from the HuggingFace cache ONLY (~/.cache/huggingface/hub).
# The backup tree /backups/huggingface/ is NOT managed here.
# Whole-repo deletions remove the repo dir; quant deletions remove the
# snapshot entries and the blobs that no remaining entry references.
set -eu

HOST="$1"
MODE="${2:-run}"

HUB="$HOME/.cache/huggingface/hub"

if [ "$MODE" = "--dry-run" ]; then
    echo "dry-run: $HOST (no deletions)"
fi

discard_repo() {
    REPO="$1"
    if [ ! -d "$HUB/$REPO" ]; then
        echo "skip  $REPO (absent)"
        return 0
    fi
    SIZE=$(du -sh "$HUB/$REPO" 2>/dev/null | cut -f1)
    if [ "$MODE" = "--dry-run" ]; then
        echo "would remove $REPO ($SIZE)"
    else
        rm -rf "$HUB/$REPO"
        echo "removed $REPO ($SIZE)"
    fi
}

discard_quant() {
    REPO="$1"
    PATTERN="$2"
    if [ ! -d "$HUB/$REPO" ]; then
        echo "skip  $REPO quant $PATTERN (repo absent)"
        return 0
    fi
    BEFORE=$(du -sb "$HUB/$REPO" 2>/dev/null | cut -f1)
    if [ "$MODE" = "--dry-run" ]; then
        MATCHED=$(find "$HUB/$REPO/snapshots" \( -type l -o -type f \) -name "*$PATTERN*" 2>/dev/null | wc -l)
        echo "would remove $MATCHED entry(ies) matching $PATTERN from $REPO"
    else
        find "$HUB/$REPO/snapshots" \( -type l -o -type f \) -name "*$PATTERN*" -delete
        for BLOB in "$HUB/$REPO"/blobs/*; do
            [ -e "$BLOB" ] || continue
            INODE=$(stat -c %i "$BLOB")
            # stat -L dereferences symlinks so a snapshot link to this blob
            # reports the blob's inode, not the link's own inode.
            if ! find "$HUB/$REPO/snapshots" \( -type l -o -type f \) -exec stat -L -c %i {} + 2>/dev/null | grep -qx "$INODE"; then
                rm -f "$BLOB"
            fi
        done
        find "$HUB/$REPO/snapshots" -type d -empty -delete 2>/dev/null || true
        AFTER=$(du -sb "$HUB/$REPO" 2>/dev/null | cut -f1)
        echo "discarded $PATTERN from $REPO ($BEFORE -> $AFTER bytes)"
    fi
}

case "$HOST" in
    athena)
        discard_repo models--unsloth--DeepSeek-R1-Distill-Llama-70B-GGUF
        discard_repo models--unsloth--Llama-3.3-70B-Instruct-GGUF
        discard_repo models--unsloth--gpt-oss-120b-GGUF
        discard_repo models--unsloth--gpt-oss-20b-GGUF
        discard_repo models--unsloth--Qwen3.5-27B-GGUF
        discard_repo models--bartowski--Qwen3.8-27B-GGUF
        discard_repo models--unsloth--Devstral-Small-2-24B-Instruct-2512-GGUF
        discard_repo models--unsloth--gemma-4-26B-A4B-it-qat-GGUF
        discard_repo models--unsloth--gemma-4-12B-it-qat-GGUF
        discard_repo models--unsloth--DeepSeek-R1-Distill-Qwen-14B-GGUF
        discard_repo models--bartowski--Mistral-Nemo-Instruct-2407-GGUF
        discard_repo models--unsloth--DeepSeek-R1-Distill-Qwen-1.5B-GGUF
        discard_repo models--unsloth--Llama-3.2-1B-Instruct-GGUF
        discard_quant models--unsloth--Llama-3.2-3B-Instruct-GGUF Q4_K_M
        ;;
    beast)
        discard_repo models--Qwen--Qwen2.5-Coder-1.5B-Instruct-GGUF
        discard_repo models--ggml-org--Qwen2.5-Coder-1.5B-Q8_0-GGUF
        discard_repo models--Qwen--Qwen2.5-Coder-3B-Instruct-GGUF
        discard_repo models--unsloth--Llama-3.2-1B-Instruct-GGUF
        discard_repo models--unsloth--Llama-3.2-3B-Instruct-GGUF
        discard_repo models--bartowski--Mistral-Nemo-Instruct-2407-GGUF
        discard_repo models--bartowski--Qwen3.8-27B-GGUF
        discard_repo models--unsloth--Qwen3.5-27B-GGUF
        discard_repo models--unsloth--DeepSeek-R1-Distill-Qwen-32B-GGUF
        discard_quant models--unsloth--gpt-oss-120b-GGUF Q4_K_M
        discard_quant models--unsloth--gpt-oss-20b-GGUF Q4_K_M
        discard_quant models--unsloth--DeepSeek-R1-Distill-Qwen-14B-GGUF Q4_K_M
        ;;
    *)
        echo "usage: sh scripts/cache-discard.sh <athena|beast> [--dry-run]" >&2
        exit 2
        ;;
esac

echo "cache-discard: done ($HOST, $MODE)"
exit 0
