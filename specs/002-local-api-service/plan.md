# Implementation Plan: 002-local-api-service

**Spec**: spec.md | **Status**: Ready | **GATE 1**: PASS | **GATE 2**: SKIP

## Overview

Build a FastAPI HTTP service that wraps `scripts/transcribe.sh` via async subprocess. Exposes POST /transcribe (file upload → JSON) and GET /health (readiness check). All processing local, all temp files deleted after use. Sequential request queuing prevents OOM from concurrent binary invocations.

## Architecture

```
Client (curl, app)
  │
  ├─ POST /transcribe (multipart file upload)
  │     │
  │     ├─ Semaphore gate (max 1 concurrent transcription)
  │     ├─ Save upload → temp file (0o700 dir)
  │     ├─ asyncio.create_subprocess_exec: scripts/transcribe.sh <temp>
  │     ├─ Parse stdout (text) + stderr (timing)
  │     ├─ Delete temp file
  │     └─ Return JSON {text, duration_seconds, processing_time_ms}
  │
  ├─ GET /health
  │     └─ Check binary, model, ffmpeg → {status, model, uptime, version}
  │
  └─ Server: uvicorn on 127.0.0.1:8000 (single worker)
```

## Dependencies

| Dep | Type | Version | Status |
|-----|------|---------|--------|
| Python | Runtime | 3.10+ | Assumed present |
| FastAPI | PyPI | >=0.115 | New |
| uvicorn | PyPI | >=0.30 | New |
| python-multipart | PyPI | >=0.0.9 | New (file uploads) |
| scripts/transcribe.sh | Internal | -- | Exists |
| qwen_asr binary | Internal | -- | Exists (make blas) |
| ffmpeg | System | -- | Assumed present |

## Tasks by User Story

### US-1: Submit Audio for Transcription (P1)

| ID | Task | Est. | Deps | [P] |
|----|------|------|------|-----|
| T1.1 | Create `api/` directory structure + `requirements.txt` | S | - | |
| T1.2 | Write `api/config.py` — settings (port, host, temp dir, queue size, max upload) | S | - | [P] |
| T1.3 | Write `api/models.py` — Pydantic response/error models | S | - | [P] |
| T1.4 | Write `api/transcribe.py` — async subprocess wrapper for transcribe.sh | M | T1.2 | |
| T1.5 | Write `api/main.py` — FastAPI app with POST /transcribe endpoint | M | T1.2, T1.3, T1.4 | |
| T1.6 | Write test: POST valid WAV → 200 with transcription text | S | T1.5 | |
| T1.7 | Write test: POST non-audio file → 400 error | S | T1.5 | [P] |
| T1.8 | Write test: POST empty file → 400 error | S | T1.5 | [P] |

### US-2: Check Service Health (P1)

| ID | Task | Est. | Deps | [P] |
|----|------|------|------|-----|
| T2.1 | Add GET /health endpoint to `api/main.py` — check binary, model, ffmpeg | S | T1.5 | |
| T2.2 | Write test: /health returns 200 when all prerequisites met | S | T2.1 | |
| T2.3 | Write test: /health returns 503 when binary/model missing | S | T2.1 | [P] |

### US-3: Start and Stop the Service (P1)

| ID | Task | Est. | Deps | [P] |
|----|------|------|------|-----|
| T3.1 | Write `scripts/start-api.sh` — validate prereqs, create venv if needed, start uvicorn, write PID file | M | T1.5 | |
| T3.2 | Write `scripts/stop-api.sh` — read PID file, send SIGTERM, clean up | S | T3.1 | |
| T3.3 | Write test: start-api.sh starts server, /health returns 200 | S | T3.1, T3.2 | |

### US-4: Handle Concurrent Requests (P2)

| ID | Task | Est. | Deps | [P] |
|----|------|------|------|-----|
| T4.1 | Add asyncio.Semaphore(1) + queue depth tracking to transcribe endpoint | S | T1.5 | |
| T4.2 | Return 429 when queue is full, include Retry-After header | S | T4.1 | |
| T4.3 | Write test: 3 concurrent requests all complete sequentially | M | T4.1 | |
| T4.4 | Write test: queue overflow returns 429 | S | T4.2 | [P] |

### Cross-Cutting: Privacy + Cleanup

| ID | Task | Est. | Deps | [P] |
|----|------|------|------|-----|
| T5.1 | Temp file cleanup in `finally` block (T1.4) | S | T1.4 | |
| T5.2 | Startup sweep of stale temp files (lifespan handler) | S | T1.5 | |
| T5.3 | Write test: temp file does not exist after successful transcription | S | T1.6 | |
| T5.4 | Write test: temp file does not exist after failed transcription | S | T1.7 | [P] |

## File Map

| File | Action | Task |
|------|--------|------|
| `api/__init__.py` | Create (empty) | T1.1 |
| `api/config.py` | Create | T1.2 |
| `api/models.py` | Create | T1.3 |
| `api/transcribe.py` | Create | T1.4 |
| `api/main.py` | Create | T1.5, T2.1, T4.1 |
| `requirements-api.txt` | Create | T1.1 |
| `scripts/start-api.sh` | Create | T3.1 |
| `scripts/stop-api.sh` | Create | T3.2 |
| `tests/test_api.py` | Create | T1.6-T5.4 |
| `tests/test-api.sh` | Create | T3.3 |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Binary not built when API starts | 503 on all requests | start-api.sh validates binary before launching; /health reports status |
| Large file upload fills disk | Service disruption | Enforce max upload size (500MB) at app level; temp dir on same partition |
| Subprocess hangs (binary crash) | Request never completes | Set subprocess timeout (5min default); kill on timeout, return 500 |
| Unclean shutdown leaves temp files | Privacy concern | Startup sweep deletes stale temp files |

## Testing Strategy

- **Unit tests** (`tests/test_api.py`): FastAPI TestClient, mock subprocess for fast tests
- **Integration test** (`tests/test-api.sh`): Start real server, POST real audio, verify JSON response
- **Coverage targets**: All endpoints, all error codes (400, 413, 429, 500, 503)
- **TDD sequence**: Write test → run (red) → implement → run (green) → refactor

## Build Sequence

1. T1.1 + T1.2 + T1.3 (parallel — scaffolding)
2. T1.4 (subprocess wrapper — core logic)
3. T1.5 + T2.1 (FastAPI app with both endpoints)
4. T4.1 + T4.2 (concurrency controls)
5. T5.1 + T5.2 (cleanup logic)
6. T3.1 + T3.2 (lifecycle scripts)
7. All tests (T1.6-T5.4)
