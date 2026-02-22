# Tasks: 002-local-api-service

**Plan**: plan.md | **Total**: 20 | **Completed**: 0

## Progress Summary
| User Story | Tasks | Done | Status |
|------------|-------|------|--------|
| Setup | 3 | 0 | Pending |
| US-1: Submit Audio | 8 | 0 | Pending |
| US-2: Health Check | 3 | 0 | Pending |
| US-3: Lifecycle | 3 | 0 | Pending |
| US-4: Concurrency | 4 | 0 | Pending |
| Cross-Cutting | 4 | 0 | Pending |
| Git | 1 | 0 | Pending |

---

## Phase 0: Setup

### T0.1: Create Directory Structure + Dependencies
- **Status**: [ ] Pending
- **Priority**: P0
- **Est**: S | **Deps**: None
- **ACs**:
  - [ ] AC-T0.1.1: `api/` directory exists with `__init__.py`
  - [ ] AC-T0.1.2: `requirements-api.txt` lists fastapi, uvicorn, python-multipart
  - [ ] AC-T0.1.3: Deps install cleanly: `pip install -r requirements-api.txt`

### T0.2: Create Config Module
- **Status**: [ ] Pending
- **Priority**: P0
- **Est**: S | **Deps**: T0.1
- **TDD Steps**:
  - [ ] T0.2.R: Write test for config defaults (port, host, temp dir, queue size, max upload)
  - [ ] T0.2.V1: Verify test FAILS
  - [ ] T0.2.G: Implement `api/config.py`
  - [ ] T0.2.V2: Verify test PASSES
  - [ ] T0.2.C1: Commit: `test(api): add config tests`
  - [ ] T0.2.C2: Commit: `feat(api): implement config module`
- **ACs**:
  - [ ] AC-T0.2.1: Config has PORT=8000, HOST=127.0.0.1
  - [ ] AC-T0.2.2: Config has TEMP_DIR, QUEUE_SIZE=10, MAX_UPLOAD_MB=500
  - [ ] AC-T0.2.3: Config reads from env vars with defaults

### T0.3: Create Response Models
- **Status**: [ ] Pending
- **Priority**: P0
- **Est**: S | **Deps**: T0.1 | **[P]**: with T0.2
- **TDD Steps**:
  - [ ] T0.3.R: Write test for Pydantic model serialization
  - [ ] T0.3.V1: Verify test FAILS
  - [ ] T0.3.G: Implement `api/models.py`
  - [ ] T0.3.V2: Verify test PASSES
  - [ ] T0.3.C1: Commit: `test(api): add response model tests`
  - [ ] T0.3.C2: Commit: `feat(api): implement response models`
- **ACs**:
  - [ ] AC-T0.3.1: TranscriptionResponse has text, duration_seconds, processing_time_ms
  - [ ] AC-T0.3.2: HealthResponse has status, model, uptime, version
  - [ ] AC-T0.3.3: ErrorResponse has detail, status_code

---

## US-1: Submit Audio for Transcription (P1)

**Story**: As a clinical developer, I want to POST an audio file to a local HTTP endpoint and receive the transcription, so that my app can integrate transcription without managing the C binary.
**Parent ACs**: AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5

### T1.1: Implement Async Subprocess Wrapper
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T0.2
- **TDD Steps**:
  - [ ] T1.1.R: Write test: wrapper calls transcribe.sh, returns text + timing
  - [ ] T1.1.V1: Verify test FAILS
  - [ ] T1.1.G: Implement `api/transcribe.py` with asyncio.create_subprocess_exec
  - [ ] T1.1.V2: Verify test PASSES
  - [ ] T1.1.B: Refactor error handling (timeout, non-zero exit)
  - [ ] T1.1.C1: Commit: `test(api): add subprocess wrapper tests`
  - [ ] T1.1.C2: Commit: `feat(api): implement async subprocess wrapper`
- **ACs**:
  - [ ] AC-T1.1.1: Calls scripts/transcribe.sh with temp file path
  - [ ] AC-T1.1.2: Returns transcription text from stdout
  - [ ] AC-T1.1.3: Parses stderr for timing info
  - [ ] AC-T1.1.4: Raises on non-zero exit code
  - [ ] AC-T1.1.5: Has configurable timeout (default 300s)

### T1.2: Implement POST /transcribe Endpoint
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T0.2, T0.3, T1.1
- **TDD Steps**:
  - [ ] T1.2.R: Write test: POST valid WAV → 200 JSON with text
  - [ ] T1.2.V1: Verify test FAILS
  - [ ] T1.2.G: Implement endpoint in `api/main.py`
  - [ ] T1.2.V2: Verify test PASSES
  - [ ] T1.2.C1: Commit: `test(api): add transcribe endpoint tests`
  - [ ] T1.2.C2: Commit: `feat(api): implement POST /transcribe`
- **ACs**:
  - [ ] AC-T1.2.1: Accepts multipart file upload (→ AC-1.1)
  - [ ] AC-T1.2.2: Returns JSON with text, duration, processing_time (→ AC-1.2)
  - [ ] AC-T1.2.3: Supports WAV, MP3, M4A, FLAC, OGG (→ AC-1.3)

### T1.3: Implement Error Responses
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T1.2
- **TDD Steps**:
  - [ ] T1.3.R: Write tests for 400, 413, 500 error cases
  - [ ] T1.3.V1: Verify tests FAIL
  - [ ] T1.3.G: Add validation + error handling
  - [ ] T1.3.V2: Verify tests PASS
  - [ ] T1.3.C1: Commit: `test(api): add error response tests`
  - [ ] T1.3.C2: Commit: `feat(api): implement error handling`
- **ACs**:
  - [ ] AC-T1.3.1: 400 for non-audio file (→ AC-1.4)
  - [ ] AC-T1.3.2: 400 for empty file upload
  - [ ] AC-T1.3.3: 413 for file > MAX_UPLOAD_MB
  - [ ] AC-T1.3.4: 500 for binary crash (→ AC-1.4)

---

## US-2: Check Service Health (P1)

**Story**: As a healthcare IT admin, I want to check if the transcription service is running and the model is loaded, so that I can monitor service availability.
**Parent ACs**: AC-2.1, AC-2.2, AC-2.3

### T2.1: Implement GET /health Endpoint
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T1.2
- **TDD Steps**:
  - [ ] T2.1.R: Write test: /health returns 200 with status, model, uptime
  - [ ] T2.1.V1: Verify test FAILS
  - [ ] T2.1.G: Implement /health in api/main.py
  - [ ] T2.1.V2: Verify test PASSES
  - [ ] T2.1.C1: Commit: `test(api): add health endpoint tests`
  - [ ] T2.1.C2: Commit: `feat(api): implement GET /health`
- **ACs**:
  - [ ] AC-T2.1.1: Returns status, model info, uptime (→ AC-2.1)
  - [ ] AC-T2.1.2: Returns version info (→ AC-2.3)

### T2.2: Implement Health 503 When Prerequisites Missing
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T2.1
- **TDD Steps**:
  - [ ] T2.2.R: Write test: /health returns 503 when binary/model missing
  - [ ] T2.2.V1: Verify test FAILS
  - [ ] T2.2.G: Add prerequisite checking
  - [ ] T2.2.V2: Verify test PASSES
  - [ ] T2.2.C1: Commit: `test(api): add health 503 tests`
  - [ ] T2.2.C2: Commit: `feat(api): health 503 for missing prereqs`
- **ACs**:
  - [ ] AC-T2.2.1: Returns 503 if binary not found (→ AC-2.2)
  - [ ] AC-T2.2.2: Returns 503 if model not downloaded (→ AC-2.2)

---

## US-3: Start and Stop the Service (P1)

**Story**: As a developer, I want to start the API server with a single command and stop it cleanly, so that I can easily manage the service lifecycle.
**Parent ACs**: AC-3.1, AC-3.2, AC-3.3, AC-3.4

### T3.1: Write start-api.sh
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T1.2
- **ACs**:
  - [ ] AC-T3.1.1: Validates binary, model, ffmpeg, Python before starting (→ AC-3.2)
  - [ ] AC-T3.1.2: Starts uvicorn on configurable port (→ AC-3.1)
  - [ ] AC-T3.1.3: Writes PID file for process management (→ AC-3.4)
  - [ ] AC-T3.1.4: Uses `set -euo pipefail`

### T3.2: Write stop-api.sh
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T3.1
- **ACs**:
  - [ ] AC-T3.2.1: Reads PID file and sends SIGTERM (→ AC-3.3)
  - [ ] AC-T3.2.2: Cleans up PID file
  - [ ] AC-T3.2.3: Handles case where process already stopped

### T3.3: Integration Test for Lifecycle
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T3.1, T3.2
- **ACs**:
  - [ ] AC-T3.3.1: start-api.sh starts server, /health returns 200
  - [ ] AC-T3.3.2: stop-api.sh stops server cleanly

---

## US-4: Handle Concurrent Requests (P2)

**Story**: As a clinical developer, I want to submit multiple transcription requests without them interfering, so that the service can handle a multi-user clinic environment.
**Parent ACs**: AC-4.1, AC-4.2, AC-4.3, AC-4.4

### T4.1: Add Semaphore + Queue Tracking
- **Status**: [ ] Pending
- **Priority**: P2
- **Est**: S | **Deps**: T1.2
- **TDD Steps**:
  - [ ] T4.1.R: Write test: requests processed sequentially
  - [ ] T4.1.V1: Verify test FAILS
  - [ ] T4.1.G: Add asyncio.Semaphore(1) + queue counter
  - [ ] T4.1.V2: Verify test PASSES
  - [ ] T4.1.C1: Commit: `test(api): add concurrency tests`
  - [ ] T4.1.C2: Commit: `feat(api): add sequential processing semaphore`
- **ACs**:
  - [ ] AC-T4.1.1: One transcription at a time (→ AC-4.1)
  - [ ] AC-T4.1.2: Queue depth tracked (→ AC-4.2)

### T4.2: Implement 429 Queue Overflow
- **Status**: [ ] Pending
- **Priority**: P2
- **Est**: S | **Deps**: T4.1
- **TDD Steps**:
  - [ ] T4.2.R: Write test: exceed queue → 429 with Retry-After
  - [ ] T4.2.V1: Verify test FAILS
  - [ ] T4.2.G: Add queue limit check
  - [ ] T4.2.V2: Verify test PASSES
  - [ ] T4.2.C1: Commit: `test(api): add 429 queue overflow test`
  - [ ] T4.2.C2: Commit: `feat(api): implement 429 for queue overflow`
- **ACs**:
  - [ ] AC-T4.2.1: Returns 429 when queue full (→ AC-4.3)
  - [ ] AC-T4.2.2: Includes Retry-After header

---

## Cross-Cutting: Privacy + Cleanup

### T5.1: Temp File Cleanup on Success
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T1.1
- **ACs**:
  - [ ] AC-T5.1.1: Temp file deleted after successful transcription (→ AC-1.5)

### T5.2: Temp File Cleanup on Failure
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T1.3 | **[P]**: with T5.1
- **ACs**:
  - [ ] AC-T5.2.1: Temp file deleted after failed transcription

### T5.3: Startup Sweep of Stale Temp Files
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T1.2
- **ACs**:
  - [ ] AC-T5.3.1: Lifespan handler deletes leftover temp files on startup

### T5.4: Temp File Verification Tests
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T5.1, T5.2
- **TDD Steps**:
  - [ ] T5.4.R: Write tests: temp file absent after success and failure
  - [ ] T5.4.V1: Verify tests FAIL
  - [ ] T5.4.G: Verify cleanup logic works
  - [ ] T5.4.V2: Verify tests PASS
  - [ ] T5.4.C1: Commit: `test(api): add temp file cleanup tests`
- **ACs**:
  - [ ] AC-T5.4.1: No temp files exist after successful request
  - [ ] AC-T5.4.2: No temp files exist after failed request

---

## Finalization

### TG-1: Git Workflow
- **Status**: [ ] Pending
- **Priority**: P0
- **Trigger**: After all tasks complete
- **Steps**:
  - [ ] TG-1.1: All tests pass
  - [ ] TG-1.2: Commit any remaining changes
  - [ ] TG-1.3: Push to main
- **ACs**:
  - [ ] All tests green
  - [ ] All code committed and pushed

---

## Dependency Graph
```
T0.1 → T0.2 → T1.1 → T1.2 → T1.3
T0.1 → T0.3 ──────↗        ↘ T2.1 → T2.2
                              ↘ T3.1 → T3.2 → T3.3
                              ↘ T4.1 → T4.2
T1.1 → T5.1 ─→ T5.4
T1.3 → T5.2 ─↗
T1.2 → T5.3
```

## Parallelization
| Group | Tasks | Reason |
|-------|-------|--------|
| 1 | T0.2, T0.3 | Independent modules |
| 2 | T2.1, T3.1, T4.1 | Independent features after T1.2 |
| 3 | T5.1, T5.2 | Independent cleanup paths |
