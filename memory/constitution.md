# Technical Constitution — qwen-asr

## Core Principles

### 1. Privacy First
- Audio data NEVER leaves the device. No telemetry, no analytics, no cloud calls.
- Model weights are downloaded once and stored locally.
- No network access during inference. The binary must work fully offline.

### 2. Upstream Compatibility
- NEVER modify upstream C source files (qwen_asr*.c, qwen_asr*.h, main.c).
- All fork additions go in separate directories: scripts/, docs/, memory/, specs/, tests/.
- Upstream's CLAUDE.md (→ AGENT.md symlink) is the source of truth for C engine behavior.
- Sync with upstream via `git fetch upstream && git merge upstream/main`.

### 3. Build Integrity
- `make blas` must always succeed on a clean checkout + Xcode CLI tools.
- No additional build dependencies beyond what upstream requires (gcc, BLAS, pthreads, libm).
- Fork tooling (scripts, tests, docs) must not interfere with upstream build.

### 4. Model Isolation
- Model directories (qwen3-asr-*/) are gitignored. Never committed.
- Download mechanism: `./download_model.sh --model small|large`.
- Scripts must check for model presence before running and give clear error messages.

### 5. Audio Pipeline Format
- Input to qwen_asr: 16-bit signed PCM, 16kHz, mono (s16le).
- Conversion from other formats: ffmpeg pipe to stdin.
- WAV files can be passed directly with `-i`.
- Scripts must validate ffmpeg availability before attempting format conversion.

## Forbidden Actions
- Modifying upstream C source or headers
- Committing model weights, API keys, or .env files
- Adding Python/Node/Rust runtime dependencies to the core transcription path
- Making network calls during transcription
- Storing patient audio in any persistent location managed by this project

## Quality Gates
- `bash scripts/quality-gate.sh` must pass before any commit
- All scripts must use `set -euo pipefail`
- All scripts must have usage/help text
- Error messages must be actionable (tell the user what to do to fix it)
