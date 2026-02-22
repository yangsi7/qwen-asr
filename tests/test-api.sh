#!/usr/bin/env bash
# Integration test for the local API service
# Requires: binary built, model downloaded, ffmpeg installed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PORT="${API_PORT:-8765}"
HOST="127.0.0.1"
PASS=0
FAIL=0
API_PID=""

usage() {
    echo "Usage: $(basename "$0")"
    echo ""
    echo "Runs integration tests against the local API service."
    echo "Starts the server, runs tests, and stops the server."
    exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

cleanup() {
    if [[ -n "$API_PID" ]] && kill -0 "$API_PID" 2>/dev/null; then
        kill "$API_PID" 2>/dev/null || true
        wait "$API_PID" 2>/dev/null || true
    fi
    rm -f "$PROJECT_DIR/.api.pid"
}
trap cleanup EXIT

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== API Integration Tests ==="
echo ""

# Pre-flight
if [[ ! -x "$PROJECT_DIR/qwen_asr" ]]; then
    echo "SKIP: Binary not built. Run 'make blas' first."
    exit 0
fi
if [[ ! -d "$PROJECT_DIR/qwen3-asr-0.6b" ]]; then
    echo "SKIP: Model not downloaded. Run './download_model.sh --model small' first."
    exit 0
fi
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "SKIP: FastAPI not installed. Run: pip install -r requirements-api.txt"
    exit 0
fi

# Start server
echo "[Starting server on port $PORT]"
cd "$PROJECT_DIR"
API_PORT="$PORT" python3 -m uvicorn api.main:app --host "$HOST" --port "$PORT" &
API_PID=$!

# Wait for startup
for i in $(seq 1 15); do
    if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo ""
echo "[Health]"
check "GET /health returns 200" curl -sf "http://$HOST:$PORT/health"
check "/health has status field" bash -c "curl -sf http://$HOST:$PORT/health | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d[\"status\"] == \"healthy\"'"
check "/health has version field" bash -c "curl -sf http://$HOST:$PORT/health | python3 -c 'import sys,json; d=json.load(sys.stdin); assert \"version\" in d'"

echo ""
echo "[Transcribe]"
if [[ -f "$PROJECT_DIR/samples/jfk.wav" ]]; then
    check "POST /transcribe with WAV" bash -c "curl -sf -F 'file=@$PROJECT_DIR/samples/jfk.wav' http://$HOST:$PORT/transcribe | python3 -c 'import sys,json; d=json.load(sys.stdin); assert len(d[\"text\"]) > 0'"
else
    echo "  SKIP: samples/jfk.wav not found"
fi

check "POST /transcribe rejects .txt" bash -c "echo 'not audio' > /tmp/test.txt && curl -sf -o /dev/null -w '%{http_code}' -F 'file=@/tmp/test.txt' http://$HOST:$PORT/transcribe | grep -q 400; rm /tmp/test.txt"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
