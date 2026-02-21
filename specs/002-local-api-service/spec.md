---
feature: 002-local-api-service
created: 2026-02-22
status: ready
priority: P1
---

# Feature: Local API Service

## Overview

FastAPI-based HTTP wrapper that exposes the qwen-asr C binary as a local REST API for transcription. Enables any application to submit audio files and receive transcriptions via HTTP, without managing the C binary directly. All processing stays on-device — no audio leaves the machine.

## Problem Statement

**What problem are we solving?**
Healthcare applications need transcription but can't easily shell out to a C binary. A local HTTP API provides a standard integration point while maintaining the privacy-first architecture.

**Who experiences this problem?**
- Clinical developers integrating transcription into web/mobile apps
- Healthcare IT teams deploying transcription as a shared local service
- Psychiatrists wanting a simple interface for session transcription

**Current situation and pain points:**
- Direct binary invocation requires shell access and ffmpeg knowledge
- No standard interface for app-to-transcription communication
- Each integration must reimplement audio format handling and error parsing
- No way to check transcription status or health of the engine

## User Stories

### US-1: Submit Audio for Transcription (Priority: P1)
**As a** clinical developer
**I want to** POST an audio file to a local HTTP endpoint and receive the transcription
**So that** my app can integrate transcription without managing the C binary

**Acceptance Criteria:**
- [ ] AC-1.1: POST /transcribe accepts multipart file upload (audio file)
- [ ] AC-1.2: Returns JSON with transcription text, duration, and processing time
- [ ] AC-1.3: Supports WAV, MP3, M4A, FLAC, OGG formats
- [ ] AC-1.4: Returns appropriate HTTP error codes (400 for bad input, 500 for engine failure)
- [ ] AC-1.5: Audio file is deleted after transcription completes (privacy)
**Test:** `curl -F "file=@test.wav" http://localhost:8000/transcribe` returns JSON with text

### US-2: Check Service Health (Priority: P1)
**As a** healthcare IT admin
**I want to** check if the transcription service is running and the model is loaded
**So that** I can monitor service availability

**Acceptance Criteria:**
- [ ] AC-2.1: GET /health returns 200 with status, model info, and uptime
- [ ] AC-2.2: Returns 503 if model not downloaded or binary not built
- [ ] AC-2.3: Response includes version info and model name
**Test:** `curl http://localhost:8000/health` returns `{"status": "healthy", ...}`

### US-3: Start and Stop the Service (Priority: P1)
**As a** developer
**I want to** start the API server with a single command and stop it cleanly
**So that** I can easily manage the service lifecycle

**Acceptance Criteria:**
- [ ] AC-3.1: `scripts/start-api.sh` starts FastAPI server on configurable port (default 8000)
- [ ] AC-3.2: Script validates binary, model, and ffmpeg before starting
- [ ] AC-3.3: `scripts/stop-api.sh` or Ctrl+C shuts down gracefully
- [ ] AC-3.4: Startup script creates a PID file for process management
**Test:** `bash scripts/start-api.sh` starts server; `/health` returns 200

### US-4: Handle Concurrent Requests (Priority: P2)
**As a** clinical developer
**I want to** submit multiple transcription requests without them interfering
**So that** the service can handle a multi-user clinic environment

**Acceptance Criteria:**
- [ ] AC-4.1: Requests are queued and processed sequentially (one binary invocation at a time)
- [ ] AC-4.2: Queue depth is limited (configurable, default: 10)
- [ ] AC-4.3: Returns 429 (Too Many Requests) when queue is full
- [ ] AC-4.4: Request includes estimated wait time in queue response
**Test:** Submit 3 concurrent requests; all complete without error

## Functional Requirements

### FR-001: Transcription Endpoint
**Priority**: P1
**Description**: POST /transcribe accepts audio file upload, invokes the C binary via subprocess, returns JSON response with transcription text

### FR-002: Health Endpoint
**Priority**: P1
**Description**: GET /health reports service status, model availability, binary presence, and system info

### FR-003: Service Lifecycle
**Priority**: P1
**Description**: Shell scripts to start/stop the FastAPI server with prerequisite validation

### FR-004: Request Queuing
**Priority**: P2
**Description**: Sequential processing queue to prevent memory exhaustion from concurrent binary invocations

### FR-005: Temporary File Management
**Priority**: P1
**Description**: Uploaded audio files are stored in a temp directory and deleted immediately after transcription completes

### FR-006: Error Handling
**Priority**: P1
**Description**: Structured JSON error responses with appropriate HTTP status codes for all failure modes

## Non-Functional Requirements

### NFR-001: Performance
- API overhead <500ms beyond raw transcription time
- File upload supports files up to 500MB (long clinical sessions)
- Response time for /health <100ms

### NFR-002: Privacy
- Zero network calls — server binds to localhost only (127.0.0.1)
- Audio files deleted immediately after transcription
- No logging of audio content or transcription text
- No telemetry or analytics

### NFR-003: Reliability
- Service starts only if all prerequisites are met (binary, model, ffmpeg)
- Graceful handling of binary crashes (return 500, don't crash server)
- Clean shutdown on SIGTERM/SIGINT

### NFR-004: Security
- Binds to localhost only by default (not 0.0.0.0)
- No authentication required (local-only service)
- File type validation before processing
- Temp directory with restricted permissions

## Technical Approach

### Architecture
```
Client → HTTP POST /transcribe → FastAPI Server
  → Save temp file → subprocess: scripts/transcribe.sh <temp-file>
  → Parse stdout → JSON response → Delete temp file
```

### Dependencies (API layer only)
- Python 3.10+
- FastAPI + uvicorn
- python-multipart (file uploads)
- No other Python dependencies

### Directory Structure
```
api/
  main.py          # FastAPI app
  config.py        # Configuration (port, queue size, temp dir)
  transcribe.py    # Subprocess wrapper
  models.py        # Pydantic response models
scripts/
  start-api.sh     # Service launcher
  stop-api.sh      # Service stopper
tests/
  test-api.sh      # API integration tests
  test_api.py      # Python unit tests
requirements.txt   # Python dependencies (api only)
```

## Constraints & Assumptions
- Subprocess-based: API calls the C binary, does NOT link to C code
- Python dependencies are isolated to the API layer (not the core engine)
- Single-instance: one server, one binary invocation at a time (queued)
- [A1] localhost-only access is sufficient for the feasibility phase
- [A2] Sequential processing is acceptable (not batch-parallel)
- [A3] Python venv managed by developer, not auto-created

## Out of Scope
- WebSocket streaming (future feature)
- Authentication/authorization
- Multi-model switching via API
- Docker containerization
- Remote (non-localhost) access
- Batch file processing endpoint
- Automatic service restart / systemd integration

## Success Criteria
- API processes audio file and returns transcription in JSON format
- Total latency: raw transcription time + <500ms overhead
- Zero audio data persisted after request completes
- Service runs stable for 8+ hours without memory leaks
- All integration tests pass

## Edge Cases
1. **Uploaded file is not audio**: Return 400 with descriptive error
2. **Binary not built**: /health returns 503; /transcribe returns 503 with "build binary first"
3. **Model not downloaded**: /health returns 503; /transcribe returns 503 with download instructions
4. **Binary crashes mid-transcription**: Return 500, clean up temp file, service stays running
5. **Very large file (>500MB)**: Return 413 (Payload Too Large) before saving
6. **Empty file upload**: Return 400 with "empty file" error
7. **Concurrent requests exceed queue**: Return 429 with retry-after header
8. **Server killed during transcription**: Temp file cleanup on next startup
