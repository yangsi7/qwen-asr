#!/usr/bin/env bash
# Stop the local transcription API service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/.api.pid"

usage() {
    echo "Usage: $(basename "$0")"
    echo ""
    echo "Stops the qwen-asr local transcription API."
    exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

if [[ ! -f "$PID_FILE" ]]; then
    echo "No PID file found. API may not be running."
    exit 0
fi

PID=$(cat "$PID_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
    echo "Process $PID not running. Cleaning up stale PID file."
    rm -f "$PID_FILE"
    exit 0
fi

echo "Stopping API (PID $PID)..."
kill "$PID"

# Wait for graceful shutdown
for i in $(seq 1 5); do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "API stopped."
        rm -f "$PID_FILE"
        exit 0
    fi
    sleep 1
done

# Force kill if still running
echo "Force-killing PID $PID..."
kill -9 "$PID" 2>/dev/null || true
rm -f "$PID_FILE"
echo "API stopped (forced)."
