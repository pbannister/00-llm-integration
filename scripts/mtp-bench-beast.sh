#!/bin/bash
#
# MTP benchmark for gpt-oss-120b on beast (task 01).
# Runs a scratch llama-server twice on port 61234: default (no speculation)
# and --spec-type draft-mtp. Reports predicted tokens/s from /v1/chat/completions.
# Run on beast: bash /tmp/mtp-bench-beast.sh
set -euo pipefail

MODEL=unsloth/gpt-oss-120b-GGUF:UD-Q4_K_XL
PORT=61234
PROMPT=$(python3 -c "print(' '.join(['The quick brown fox jumps over the lazy dog and considers the nature of speculative decoding in modern language models.']*12))")

run_bench() {
    local TAG="$1"
    shift
    echo "=== bench $TAG $(date +%H:%M:%S)"
    nohup llama-server -hf "$MODEL" --host 127.0.0.1 --port "$PORT" -c 4096 -ngl 0 "$@" >"/tmp/mtp-bench-$TAG.log" 2>&1 &
    local PID=$!
    local READY=0
    for _ in $(seq 1 150); do
        if curl -s -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
            READY=1
            break
        fi
        sleep 2
    done
    if [ "$READY" -ne 1 ]; then
        echo "bench $TAG: server did not become ready; log tail:"
        tail -5 "/tmp/mtp-bench-$TAG.log"
        kill "$PID" 2>/dev/null || true
        return 1
    fi
    curl -s -m 600 "http://127.0.0.1:$PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"x\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":128,\"stream\":false}" \
        | python3 -c "import json,sys; d=json.load(sys.stdin); t=d.get('timings',{}); print('RESULT $TAG pred_tok_s=%.2f prompt_tok_s=%.2f' % (t.get('predicted_per_second',0), t.get('prompt_per_second',0)))"
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    sleep 2
}

run_bench none
run_bench draft-mtp --spec-type draft-mtp
echo "=== done $(date +%H:%M:%S)"
