#!/usr/bin/env bash
# Medical audio latency benchmark for qwen-asr
# Measures transcription time and memory usage for various audio durations
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/qwen_asr"
MODEL_DIR="$PROJECT_DIR/qwen3-asr-0.6b"
AUDIO_DIR="$SCRIPT_DIR/medical-audio"
TIME_BIN="/usr/bin/time"

FULL_MODE=0
DURATIONS=(60 300)  # 1min, 5min in seconds

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Benchmarks qwen-asr transcription latency and memory on medical audio."
    echo "Default: tests 1min and 5min audio durations."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help text"
    echo "  --full         Also test 15min and 30min durations (slow — real-time TTS)"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --full) FULL_MODE=1; shift ;;
        *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ "$FULL_MODE" -eq 1 ]]; then
    DURATIONS=(60 300 900 1800)  # 1min, 5min, 15min, 30min
fi

# Prerequisites
echo "=== Medical Audio Latency Benchmark ==="
echo ""
echo "[Prerequisites]"

PREREQ_FAIL=0

if [[ -x "$BINARY" ]]; then
    echo "  PASS: binary exists"
else
    echo "  FAIL: binary not found at $BINARY"
    PREREQ_FAIL=1
fi

if [[ -f "$MODEL_DIR/vocab.json" ]]; then
    echo "  PASS: model exists"
else
    echo "  FAIL: model not found at $MODEL_DIR"
    PREREQ_FAIL=1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "  FAIL: ffmpeg not found"
    PREREQ_FAIL=1
else
    echo "  PASS: ffmpeg available"
fi

if [[ ! -x "$TIME_BIN" ]]; then
    echo "  FAIL: $TIME_BIN not found (BSD time binary required)"
    PREREQ_FAIL=1
else
    echo "  PASS: /usr/bin/time available"
fi

if ! command -v say &>/dev/null; then
    echo "  FAIL: say command not found (macOS required)"
    PREREQ_FAIL=1
else
    echo "  PASS: say command available"
fi

if [[ "$PREREQ_FAIL" -eq 1 ]]; then
    echo ""
    echo "Prerequisites failed. Aborting."
    exit 1
fi

# Check if category WAVs exist (needed as base audio)
BASE_WAVS=()
for wav in "$AUDIO_DIR"/*.wav; do
    [[ -f "$wav" ]] && BASE_WAVS+=("$wav")
done

if [[ ${#BASE_WAVS[@]} -eq 0 ]]; then
    echo ""
    echo "  No base WAV files found. Run: bash scripts/generate-medical-test-audio.sh"
    exit 1
fi
echo "  PASS: ${#BASE_WAVS[@]} base WAV files available"

# Helper: generate audio of target duration by concatenating and padding
generate_long_audio() {
    local target_secs="$1"
    local output_file="$2"

    # Create a concat list from available WAVs
    local concat_list
    concat_list=$(mktemp)
    trap "rm -f '$concat_list'" RETURN

    # Calculate how many loops we need
    # Get total duration of base WAVs
    local total_base_dur=0
    for wav in "${BASE_WAVS[@]}"; do
        local dur
        dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$wav" 2>/dev/null || echo "0")
        total_base_dur=$(echo "$total_base_dur + $dur" | bc 2>/dev/null || echo "$total_base_dur")
    done

    # If total_base_dur is 0, generate via TTS directly
    if [[ $(echo "$total_base_dur < 1" | bc 2>/dev/null || echo "1") -eq 1 ]]; then
        echo "    Generating ${target_secs}s audio via TTS (no base WAVs with duration)..."
        # Generate a long text and use TTS
        local long_text
        long_text=$(mktemp)
        local aiff_tmp
        aiff_tmp=$(mktemp -u).aiff
        for i in $(seq 1 $((target_secs / 10 + 1))); do
            echo "The patient presents with symptoms requiring clinical evaluation. Blood pressure is normal. Heart rate is stable." >> "$long_text"
        done
        say -v Samantha -o "$aiff_tmp" < "$long_text"
        ffmpeg -y -i "$aiff_tmp" -ar 16000 -ac 1 -t "$target_secs" "$output_file" 2>/dev/null
        rm -f "$long_text" "$aiff_tmp"
        return
    fi

    # Build concat list repeating WAVs until we exceed target duration
    local accumulated=0
    while (( $(echo "$accumulated < $target_secs" | bc) )); do
        for wav in "${BASE_WAVS[@]}"; do
            echo "file '$wav'" >> "$concat_list"
            local dur
            dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$wav" 2>/dev/null || echo "20")
            accumulated=$(echo "$accumulated + $dur" | bc)
            if (( $(echo "$accumulated >= $target_secs" | bc) )); then
                break
            fi
        done
    done

    # Concatenate and trim to exact duration
    ffmpeg -y -f concat -safe 0 -i "$concat_list" -ar 16000 -ac 1 -t "$target_secs" "$output_file" 2>/dev/null
    rm -f "$concat_list"
}

# Run latency tests
echo ""
echo "[Latency Tests]"

for dur_secs in "${DURATIONS[@]}"; do
    dur_label="${dur_secs}s"
    if [[ "$dur_secs" -ge 60 ]]; then
        dur_label="$((dur_secs / 60))min"
    fi

    echo ""
    echo "  --- $dur_label ($dur_secs seconds) ---"

    # Generate test audio
    LONG_WAV=$(mktemp -u).wav
    echo "    Generating ${dur_label} test audio..."
    generate_long_audio "$dur_secs" "$LONG_WAV"

    if [[ ! -f "$LONG_WAV" ]] || [[ ! -s "$LONG_WAV" ]]; then
        echo "    FAIL: Could not generate ${dur_label} audio"
        continue
    fi

    ACTUAL_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$LONG_WAV" 2>/dev/null || echo "unknown")
    echo "    Audio duration: ${ACTUAL_DUR}s"

    # Transcribe with timing
    echo "    Transcribing..."
    TIME_OUTPUT=$(mktemp)
    TRANSCRIPT_OUTPUT=$(mktemp)
    STDERR_OUTPUT=$(mktemp)

    # Use /usr/bin/time to capture memory; do NOT use --silent so binary outputs timing to stderr
    "$TIME_BIN" -l "$BINARY" -d "$MODEL_DIR" -i "$LONG_WAV" \
        > "$TRANSCRIPT_OUTPUT" 2> "$STDERR_OUTPUT" || true

    # Parse results from stderr
    # qwen_asr timing line: "Audio: <audio_s> s processed in <infer_s> s (<x>x realtime)"
    REALTIME_FACTOR=$(grep -oE '[0-9]+\.[0-9]+x realtime' "$STDERR_OUTPUT" | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
    INFERENCE_MS=$(grep -oE 'Inference: [0-9]+ ms' "$STDERR_OUTPUT" | head -1 | grep -oE '[0-9]+' || echo "N/A")

    # Parse peak memory from /usr/bin/time -l output (macOS: bytes)
    PEAK_MEM_BYTES=$(grep 'maximum resident set size' "$STDERR_OUTPUT" | grep -oE '[0-9]+' | head -1 || echo "0")
    if [[ -n "$PEAK_MEM_BYTES" ]] && [[ "$PEAK_MEM_BYTES" -gt 0 ]]; then
        PEAK_MEM_MB=$((PEAK_MEM_BYTES / 1048576))
    else
        PEAK_MEM_MB="N/A"
    fi

    WORD_COUNT=$(wc -w < "$TRANSCRIPT_OUTPUT" | tr -d ' ')

    echo "    Results:"
    echo "      Words transcribed: $WORD_COUNT"
    echo "      Realtime factor:   ${REALTIME_FACTOR}x"
    echo "      Inference time:    ${INFERENCE_MS}ms"
    echo "      Peak memory:       ${PEAK_MEM_MB}MB"

    # Cleanup
    rm -f "$LONG_WAV" "$TIME_OUTPUT" "$TRANSCRIPT_OUTPUT" "$STDERR_OUTPUT"
done

echo ""
echo "=== Latency Benchmark Complete ==="
