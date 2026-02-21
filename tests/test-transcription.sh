#!/usr/bin/env bash
# Transcription regression tests for qwen-asr
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/qwen_asr"
MODEL_DIR="$PROJECT_DIR/qwen3-asr-0.6b"
TEST_AUDIO="/Users/yangsim/Nanoleq/sideProjects/transcribe/uploads/test-audio/audio-to-transcribe-test.mp3"
PASS=0
FAIL=0

check() {
    local name="$1"
    shift
    if eval "$@" >/dev/null 2>&1; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Transcription Tests ==="
echo ""

# Prerequisites
echo "[Prerequisites]"
check "binary exists" "test -x '$BINARY'"
check "model dir exists" "test -d '$MODEL_DIR'"
check "vocab.json exists" "test -f '$MODEL_DIR/vocab.json'"
check "ffmpeg available" "command -v ffmpeg"
check "test audio exists" "test -f '$TEST_AUDIO'"

# Help flag
echo ""
echo "[CLI]"
check "--help works" "'$BINARY' --help 2>&1 | grep -q 'Usage'"

# Transcription via ffmpeg pipe (MP3 → stdin)
echo ""
echo "[Transcription]"
if [[ -f "$TEST_AUDIO" ]] && [[ -f "$MODEL_DIR/vocab.json" ]]; then
    echo "  Running MP3 transcription via ffmpeg pipe..."
    RESULT=$(ffmpeg -i "$TEST_AUDIO" -f s16le -ar 16000 -ac 1 - 2>/dev/null | \
        "$BINARY" -d "$MODEL_DIR" --stdin --silent 2>/dev/null)

    if [[ -n "$RESULT" ]]; then
        WORD_COUNT=$(echo "$RESULT" | wc -w | tr -d ' ')
        echo "  PASS: MP3 transcription produced output ($WORD_COUNT words)"
        PASS=$((PASS + 1))

        # Check for non-trivial output (at least 10 words for a real audio file)
        if [[ "$WORD_COUNT" -ge 10 ]]; then
            echo "  PASS: Output is non-trivial (>= 10 words)"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: Output seems too short ($WORD_COUNT words)"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  FAIL: MP3 transcription produced empty output"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  SKIP: Missing test audio or model vocab"
fi

# Streaming mode test
echo ""
echo "[Streaming]"
if [[ -f "$TEST_AUDIO" ]] && [[ -f "$MODEL_DIR/vocab.json" ]]; then
    STREAM_RESULT=$(ffmpeg -i "$TEST_AUDIO" -f s16le -ar 16000 -ac 1 -t 10 - 2>/dev/null | \
        "$BINARY" -d "$MODEL_DIR" --stdin --stream --silent 2>/dev/null)
    if [[ -n "$STREAM_RESULT" ]]; then
        echo "  PASS: Streaming mode produced output"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: Streaming mode produced empty output"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  SKIP: Missing test audio or model vocab"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
