#!/usr/bin/env bash
# Generate WAV test audio from medical terminology text files using macOS TTS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AUDIO_DIR="$PROJECT_DIR/tests/medical-audio"
VOICE="Samantha"

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Generates WAV test audio files from .text files in tests/medical-audio/"
    echo "using macOS TTS (say -v $VOICE) and ffmpeg for format conversion."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help text"
    echo "  -v, --voice    TTS voice to use (default: $VOICE)"
    echo "  --force        Regenerate even if WAV already exists"
    echo ""
    echo "Output: tests/medical-audio/<category>.wav (16kHz mono)"
    exit 0
}

FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -v|--voice) VOICE="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Prerequisites
if ! command -v say &>/dev/null; then
    echo "Error: 'say' command not found. This script requires macOS." >&2
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg is required but not found. Install with: brew install ffmpeg" >&2
    exit 1
fi

if [[ ! -d "$AUDIO_DIR" ]]; then
    echo "Error: Audio directory not found: $AUDIO_DIR" >&2
    exit 1
fi

# Check voice is available
if ! say -v '?' | grep -q "^${VOICE} "; then
    echo "Error: TTS voice '$VOICE' not found. Available voices:" >&2
    say -v '?' | head -20 >&2
    exit 1
fi

echo "=== Medical Test Audio Generation ==="
echo "Voice: $VOICE"
echo "Output: $AUDIO_DIR"
echo ""

GENERATED=0
SKIPPED=0

for TEXT_FILE in "$AUDIO_DIR"/*.text; do
    [[ -f "$TEXT_FILE" ]] || continue

    BASENAME="$(basename "$TEXT_FILE" .text)"
    WAV_FILE="$AUDIO_DIR/${BASENAME}.wav"
    AIFF_FILE="$AUDIO_DIR/${BASENAME}.aiff"

    if [[ -f "$WAV_FILE" ]] && [[ "$FORCE" -eq 0 ]]; then
        echo "  SKIP: $BASENAME.wav (already exists, use --force to regenerate)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "  Generating: $BASENAME.wav ..."

    # TTS → AIFF
    say -v "$VOICE" -o "$AIFF_FILE" < "$TEXT_FILE"

    # AIFF → WAV (16kHz mono, s16le) — trap ensures AIFF cleanup even if ffmpeg fails
    cleanup_aiff() { rm -f "$AIFF_FILE"; }
    trap cleanup_aiff EXIT

    ffmpeg -y -i "$AIFF_FILE" -ar 16000 -ac 1 "$WAV_FILE" 2>/dev/null

    # Clean up intermediate AIFF (normal path)
    rm -f "$AIFF_FILE"
    trap - EXIT

    # Verify output
    if [[ -f "$WAV_FILE" ]] && [[ -s "$WAV_FILE" ]]; then
        DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$WAV_FILE" 2>/dev/null || echo "unknown")
        echo "    OK: ${DURATION}s"
        GENERATED=$((GENERATED + 1))
    else
        echo "    FAIL: WAV file is empty or missing"
        exit 1
    fi
done

echo ""
echo "=== Done: $GENERATED generated, $SKIPPED skipped ==="
