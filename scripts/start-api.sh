#!/usr/bin/env bash
# Start the local transcription API service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/.api.pid"
PORT="${API_PORT:-8000}"
HOST="${API_HOST:-127.0.0.1}"

usage() {
    echo "Usage: $(basename "$0") [--port PORT] [--host HOST]"
    echo ""
    echo "Starts the qwen-asr local transcription API."
    echo ""
    echo "Options:"
    echo "  --port PORT  Port to listen on (default: 8000, env: API_PORT)"
    echo "  --host HOST  Host to bind to (default: 127.0.0.1, env: API_HOST)"
    echo "  -h, --help   Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

echo "=== qwen-asr API Pre-flight ==="

# Check prerequisites
if [[ ! -x "$PROJECT_DIR/qwen_asr" ]]; then
    echo "FAIL: Binary not found. Run 'make blas' first." >&2
    exit 1
fi
echo "  OK: Binary found"

if [[ ! -d "$PROJECT_DIR/qwen3-asr-0.6b" ]]; then
    echo "FAIL: Model not found. Run './download_model.sh --model small' first." >&2
    exit 1
fi
echo "  OK: Model found"

if ! command -v ffmpeg &>/dev/null; then
    echo "FAIL: ffmpeg not found. Install with: brew install ffmpeg" >&2
    exit 1
fi
echo "  OK: ffmpeg found"

if ! command -v python3 &>/dev/null; then
    echo "FAIL: python3 not found." >&2
    exit 1
fi
echo "  OK: python3 found"

# Check if already running
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "API already running (PID $OLD_PID). Stop it first with scripts/stop-api.sh" >&2
        exit 1
    fi
    rm -f "$PID_FILE"
fi

# Check deps
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "FAIL: FastAPI not installed. Run: pip install -r requirements-api.txt" >&2
    exit 1
fi
echo "  OK: FastAPI installed"

echo ""
echo "Starting API on $HOST:$PORT ..."

# Start uvicorn in background
cd "$PROJECT_DIR"
API_PORT="$PORT" API_HOST="$HOST" \
    python3 -m uvicorn api.main:app --host "$HOST" --port "$PORT" &
API_PID=$!
echo "$API_PID" > "$PID_FILE"

# Wait for startup
for i in $(seq 1 10); do
    if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
        echo "API running (PID $API_PID) at http://$HOST:$PORT"
        echo "  Health: http://$HOST:$PORT/health"
        echo "  Transcribe: POST http://$HOST:$PORT/transcribe"
        echo "  Stop: bash scripts/stop-api.sh"
        exit 0
    fi
    sleep 1
done

echo "WARNING: API started but health check not responding yet. PID: $API_PID"
