# Architecture — qwen-asr (Living Document)

## System Overview

```
┌─────────────────────────────────────────────┐
│              Application Layer               │
│   (Future: FastAPI wrapper, Tauri app, etc.) │
└──────────────────┬──────────────────────────┘
                   │ subprocess / stdin pipe
                   ▼
┌─────────────────────────────────────────────┐
│          qwen_asr C Binary (CPU)            │
│  ┌─────────┐ ┌────────┐ ┌──────────────┐   │
│  │  Audio   │ │Encoder │ │   Decoder    │   │
│  │Processing│→│(Xformer│→│(Qwen3 LLM + │   │
│  │ (mel)    │ │+SIMD)  │ │  KV cache)   │   │
│  └─────────┘ └────────┘ └──────────────┘   │
│       ↑                         │           │
│  s16le 16kHz               BPE tokens       │
│  mono input                → stdout text    │
└─────────────────────────────────────────────┘
                   ↑
                   │ ffmpeg conversion
                   │
┌─────────────────────────────────────────────┐
│           Audio Source                        │
│  MP3, M4A, OGG, FLAC, WAV, WebM, etc.      │
└─────────────────────────────────────────────┘
```

## Current State (Phase 1: Feasibility)
- C binary built and verified (ARM64, Apple Accelerate BLAS)
- 0.6B model downloaded
- Shell scripts for transcription, quality gate, testing
- Documentation and SDD artifacts

## Planned Architecture (Phase 2: Local API)

```
┌────────────────────────────┐
│     Client Application     │
│  (Web UI, Desktop App,     │
│   CLI, mobile app)         │
└────────────┬───────────────┘
             │ HTTP (localhost only)
             ▼
┌────────────────────────────┐
│     FastAPI Local Server   │
│  - POST /transcribe        │
│  - POST /transcribe/stream │
│  - GET /health             │
│  - Audit logging           │
│  - Request validation      │
└────────────┬───────────────┘
             │ subprocess.run()
             ▼
┌────────────────────────────┐
│     qwen_asr C Binary      │
│  (stdin pipe, --silent)    │
└────────────────────────────┘
```

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ASR engine | antirez/qwen-asr (C) | Fastest CPU inference, zero deps, single binary |
| Model size | 0.6B (small) | Best speed/quality tradeoff for CPU, ~2.8GB RAM |
| Input format | ffmpeg → s16le pipe | Universal format support without modifying C binary |
| API wrapper | FastAPI (planned) | User's familiar stack, matches transcribe project |
| Binding strategy | subprocess (not FFI) | Simpler, safer, upstream-compatible |
| Deployment | Local only | HIPAA compliance, zero cloud dependency |

## Constraints
- macOS Apple Silicon primary target (Linux secondary)
- No GPU acceleration (upstream design decision)
- No modifications to upstream C source
- All data stays on-device
