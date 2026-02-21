# Local Setup Guide (Fork-Specific)

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- Xcode Command Line Tools: `xcode-select --install`
- ffmpeg: `brew install ffmpeg`
- GitHub CLI: `brew install gh`

## Quick Start

```bash
# Clone this fork
git clone https://github.com/yangsi7/qwen-asr.git
cd qwen-asr

# Build
make blas

# Download 0.6B model (~1.9 GB)
./download_model.sh --model small

# Test transcription
bash scripts/transcribe.sh /path/to/audio.mp3
```

## Git Remote Setup

This fork maintains two remotes:

```bash
git remote -v
# origin    github.com:yangsi7/qwen-asr.git (fetch/push)
# upstream  github.com:antirez/qwen-asr.git (fetch/push)
```

## Syncing with Upstream

```bash
git fetch upstream
git merge upstream/main
# Resolve conflicts if any, then push
git push origin main
```

## Installing Git Hooks

```bash
bash scripts/install-hooks.sh
```

This sets `core.hooksPath` to `.githooks/` which blocks:
- Model files (*.safetensors, *.bin, *.gguf)
- Secret files (*.env, .mcp.json)
- Files >10MB

## Running Tests

```bash
# Quality gate (build + smoke tests)
bash scripts/quality-gate.sh

# Transcription tests (requires model + test audio)
bash tests/test-transcription.sh
```

## Performance Notes

On Apple M-series (0.6B model):
- Short audio (<60s): Use default (`-S 0`), ~8x realtime
- Long audio (>60s): Use `-S 20` for segmented mode, ~10-13x realtime
- Streaming: Use `--stream` for live audio only (slower for files)
