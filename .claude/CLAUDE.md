# qwen-asr — Fork Toolkit Reference

## Project Identity
Local medical transcription feasibility project. Fork of antirez/qwen-asr (pure C ASR engine).
Privacy-first: all audio stays on-device. No cloud calls during inference.

## Tech Stack
- **Engine**: C11 with Apple Accelerate BLAS, ARM NEON SIMD
- **Model**: Qwen3-ASR 0.6B (~1.9GB weights, ~2.8GB runtime memory)
- **Audio**: ffmpeg for format conversion → s16le 16kHz mono pipe
- **Future API**: FastAPI (Python) subprocess wrapper
- **Build**: gcc, make blas

## Commands

### Build & Run
```bash
make blas                                    # Build binary
./qwen_asr -d qwen3-asr-0.6b -i audio.wav  # Transcribe WAV
bash scripts/transcribe.sh audio.mp3         # Transcribe any format
```

### Quality & Testing
```bash
bash scripts/quality-gate.sh     # Build + smoke tests
bash tests/test-transcription.sh # Transcription regression tests
```

### Git
```bash
git fetch upstream && git merge upstream/main  # Sync with antirez
bash scripts/install-hooks.sh                  # Install pre-commit guards
```

## Critical Rules

### DO NOT
- Modify upstream C source files (qwen_asr*.c, qwen_asr*.h, main.c)
- Commit model weights, API keys, .env, or .mcp.json files
- Add network calls to the transcription pipeline
- Add Python/Node runtime dependencies to the core C engine path

### ALWAYS
- Keep fork additions in: scripts/, docs/, memory/, specs/, tests/
- Check model + ffmpeg availability before running transcription commands
- Use `set -euo pipefail` in all shell scripts
- Run quality-gate.sh before committing

## Key Files

### Upstream (DO NOT EDIT)
- `main.c` — CLI entry point
- `qwen_asr.c` — Transcription orchestration
- `qwen_asr.h` — Public API
- `AGENT.md` (→ CLAUDE.md symlink) — Upstream agent guide
- `Makefile` — Build targets

### Fork Additions
- `scripts/transcribe.sh` — Universal audio transcription wrapper
- `scripts/quality-gate.sh` — Build + smoke test pipeline
- `tests/test-transcription.sh` — Transcription regression tests
- `docs/architecture.md` — System architecture
- `docs/local-setup.md` — Fork-specific setup guide
- `memory/product.md` — SDD product definition
- `memory/constitution.md` — Technical constitution
- `memory/architecture.md` — Living architecture document

## Navigation
- Upstream engine docs: `AGENT.md` (root)
- Model details: `MODEL.md`, `MODEL_CARD_OFFICIAL.md`
- Fork architecture: `docs/architecture.md`
- Product context: `memory/product.md`
- Technical rules: `memory/constitution.md`
