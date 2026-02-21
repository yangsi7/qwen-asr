#!/usr/bin/env bash
# Universal audio transcription wrapper for qwen-asr
# Accepts any audio format (ffmpeg converts to s16le 16kHz mono → stdin pipe)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/qwen_asr"
MODEL_DIR="$PROJECT_DIR/qwen3-asr-0.6b"

usage() {
    echo "Usage: $(basename "$0") <audio-file> [qwen_asr options...]"
    echo ""
    echo "Transcribes any audio file using Qwen3-ASR."
    echo "Supports: mp3, m4a, ogg, flac, wav, webm, and any ffmpeg-supported format."
    echo ""
    echo "Options passed through to qwen_asr (e.g., --stream, --silent, --language en)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") recording.mp3"
    echo "  $(basename "$0") session.m4a --silent"
    echo "  $(basename "$0") interview.wav --stream"
    exit 1
}

[[ $# -lt 1 ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

INPUT_FILE="$1"
shift

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

if [[ ! -x "$BINARY" ]]; then
    echo "Error: Binary not found at $BINARY. Run 'make blas' first." >&2
    exit 1
fi

if [[ ! -d "$MODEL_DIR" ]]; then
    echo "Error: Model not found at $MODEL_DIR. Run './download_model.sh --model small' first." >&2
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg is required but not found. Install with: brew install ffmpeg" >&2
    exit 1
fi

# If already a WAV file, try direct input first
if [[ "$INPUT_FILE" == *.wav ]]; then
    exec "$BINARY" -d "$MODEL_DIR" -i "$INPUT_FILE" "$@"
fi

# For all other formats, pipe through ffmpeg
ffmpeg -i "$INPUT_FILE" -f s16le -ar 16000 -ac 1 - 2>/dev/null | \
    "$BINARY" -d "$MODEL_DIR" --stdin "$@"
