#!/bin/sh
#
# kokoro-tts.sh: start a local Kokoro-82M text-to-speech server on a loopback
# port, following the FIM server pattern that llama.vscode already uses.
#
# Kokoro-82M is the speech-synthesis choice recorded in
# documents/18-voice-and-speech-models.md (measured 2026-11-24):
#   270 MB on disk, 2.5x realtime on CPU alone, 54 voices, Apache-2.0.
# The GPU adds nothing for this model, so the default is CPU; pass --gpu to
# offload anyway.
#
# The server is llama-server, which serves the OpenAI-compatible
# POST /v1/audio/speech endpoint. A client that speaks the OpenAI API can use
# it directly; no separate speech engine is involved.
#
# Speech models are deliberately NOT in the router preset: the router
# advertises every model in its preset and its cache to the whole subnet, and
# a speech model has no business there. This script keeps the model in its own
# directory and its own port.
#
# Usage: sh scripts/kokoro-tts.sh [--gpu] [--port N] [--stop] [--status]
#
#   --gpu        offload to Vulkan (ngl 99); the default is CPU
#   --port N     listen port (default 8013)
#   --stop       stop a server this script started
#   --status     report whether it is running
#
# Environment:
#   KOKORO_DIR   model directory (default ~/.cache/kokoro-tts)
#
# Exit status: 0 on success; 1 when the server failed to become healthy.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

PATH_LLAMA_SERVER=/usr/local/bin/llama-server
PATH_MODEL_DIR=${KOKORO_DIR:-$HOME/.cache/kokoro-tts}
NAME_REPO_MODEL=ggml-org/Kokoro-82M-GGUF
NAME_FILE_MODEL=Kokoro-82M-F32.gguf
NAME_FILE_MMPROJ=mmproj-Kokoro-82M-F16.gguf
PORT=8013
GPU=0
ACTION=start

while [ $# -gt 0 ]; do
    case $1 in
        --gpu) GPU=1 ;;
        --port)
            shift
            [ $# -gt 0 ] || { echo "kokoro-tts: --port needs a value" >&2; exit 2; }
            PORT=$1
            ;;
        --stop) ACTION=stop ;;
        --status) ACTION=status ;;
        *)
            echo "kokoro-tts: unknown option: $1" >&2
            exit 2
            ;;
    esac
    shift
done

case $PORT in
    *[!0-9]* | '')
        echo "kokoro-tts: port is not a number: $PORT" >&2
        exit 2
        ;;
esac

FILE_PID="$PATH_MODEL_DIR/kokoro-tts.pid"
FILE_LOG="$PATH_MODEL_DIR/kokoro-tts.log"

# is_running: true when the pid file names a live llama-server on this port.
is_running() {
    [ -f "$FILE_PID" ] || return 1
    PID=$(cat "$FILE_PID" 2>/dev/null) || return 1
    [ -n "$PID" ] || return 1
    kill -0 "$PID" 2>/dev/null || return 1
    return 0
}

if [ "$ACTION" = "stop" ]; then
    if is_running; then
        PID=$(cat "$FILE_PID")
        kill "$PID" 2>/dev/null || true
        # Give it a moment to exit, then insist.
        TRIES=0
        while [ $TRIES -lt 20 ] && kill -0 "$PID" 2>/dev/null; do
            sleep 0.25
            TRIES=$((TRIES + 1))
        done
        kill -9 "$PID" 2>/dev/null || true
        rm -f "$FILE_PID"
        echo "kokoro-tts: stopped (pid $PID)"
    else
        echo "kokoro-tts: not running"
        rm -f "$FILE_PID"
    fi
    exit 0
fi

if [ "$ACTION" = "status" ]; then
    if is_running; then
        echo "kokoro-tts: running (pid $(cat "$FILE_PID"), port $PORT)"
        if curl -sf -m 3 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
            echo "kokoro-tts: healthy"
        else
            echo "kokoro-tts: not answering /health"
        fi
    else
        echo "kokoro-tts: not running"
    fi
    exit 0
fi

if [ ! -x "$PATH_LLAMA_SERVER" ]; then
    echo "kokoro-tts: missing $PATH_LLAMA_SERVER" >&2
    exit 1
fi

if is_running; then
    echo "kokoro-tts: already running (pid $(cat "$FILE_PID"), port $PORT)"
    exit 0
fi

mkdir -p "$PATH_MODEL_DIR"

# Fetch the two GGUF files once. llama-server's own -hf download would also
# work, but an explicit fetch keeps the model in this set's directory and out
# of the shared HuggingFace cache the router advertises.
fetch_file() {
    NAME_FILE=$1
    if [ -s "$PATH_MODEL_DIR/$NAME_FILE" ]; then
        return 0
    fi
    echo "kokoro-tts: downloading $NAME_FILE"
    if ! curl -fL --retry 3 -o "$PATH_MODEL_DIR/$NAME_FILE.part" \
        "https://huggingface.co/$NAME_REPO_MODEL/resolve/main/$NAME_FILE"; then
        rm -f "$PATH_MODEL_DIR/$NAME_FILE.part"
        echo "kokoro-tts: download failed: $NAME_FILE" >&2
        return 1
    fi
    mv "$PATH_MODEL_DIR/$NAME_FILE.part" "$PATH_MODEL_DIR/$NAME_FILE"
}

fetch_file "$NAME_FILE_MODEL" || exit 1
fetch_file "$NAME_FILE_MMPROJ" || exit 1

if [ "$GPU" = "1" ]; then
    NGL=99
    WHERE="GPU"
else
    NGL=0
    WHERE="CPU"
fi

echo "kokoro-tts: starting on 127.0.0.1:$PORT ($WHERE, model in $PATH_MODEL_DIR)"
nohup "$PATH_LLAMA_SERVER" \
    -m "$PATH_MODEL_DIR/$NAME_FILE_MODEL" \
    -mm "$PATH_MODEL_DIR/$NAME_FILE_MMPROJ" \
    --host 127.0.0.1 \
    --port "$PORT" \
    --alias kokoro \
    --n-gpu-layers "$NGL" \
    --no-webui \
    >"$FILE_LOG" 2>&1 &
PID=$!
echo "$PID" >"$FILE_PID"

# Wait for health, then say so. A server that never answers is a failure, not
# a slow start: the caller needs to know before it sends audio.
TRIES=0
while [ $TRIES -lt 120 ]; do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "kokoro-tts: server exited during startup; last log lines:" >&2
        tail -20 "$FILE_LOG" >&2 || true
        rm -f "$FILE_PID"
        exit 1
    fi
    if curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        echo "kokoro-tts: healthy on http://127.0.0.1:$PORT (pid $PID)"
        echo "kokoro-tts: POST /v1/audio/speech  (OpenAI-compatible)"
        exit 0
    fi
    sleep 0.5
    TRIES=$((TRIES + 1))
done

echo "kokoro-tts: not healthy after 60 s; last log lines:" >&2
tail -20 "$FILE_LOG" >&2 || true
echo "kokoro-tts: stopping the failed server" >&2
kill "$PID" 2>/dev/null || true
rm -f "$FILE_PID"
exit 1
