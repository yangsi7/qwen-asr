# SDD Audit Trail — qwen-asr

## 2026-02-22: Specifications Created

All 3 feature specs written and committed at `ecea144`.

### GATE 1 Results: ALL PASS

| Metric | 001-core-transcription | 002-local-api-service | 003-medical-feasibility-testing | Required |
|--------|------------------------|-----------------------|---------------------------------|----------|
| `[NEEDS CLARIFICATION]` markers | 0 | 0 | 0 | 0 |
| User Stories | 3 | 4 | 4 | -- |
| ACs per story (min) | 3 | 3 | 4 | >=2 |
| Functional Requirements | 5 | 6 | 5 | >=3 |
| Edge Cases documented | 6 | 8 | 6 | -- |

**Verdict**: All specs pass GATE 1 criteria. No clarification markers, sufficient user stories, acceptance criteria, and functional requirements.

### GATE 2: SKIP

**Reason**: Complexity score 0-2 (first feature +2, simple CLI/shell indicators -2). Per `complexity-detection.md`, scores 1-3 route to `/sdd` solo mode. GATE 2 validators (frontend, auth, data-layer) are not applicable to a pure C binary project with shell script tooling.

### Routing Decision

- Complexity: 0-2 (solo mode)
- Team: Not required
- Remaining phases proceed via `/sdd` solo workflow

### Process Note

Specs were written by general-purpose agents during the session rather than through the SDD interview workflow. User provided all context directly. Interview artifacts (`.sdd/features/*/interview-round-*.md`) were not generated because no structured interviews occurred. The specs themselves are complete and pass GATE 1.

## 2026-02-22: Phase 5 Planning — 002-local-api-service

### Artifacts Created
- `specs/002-local-api-service/plan.md` — 20 tasks across 4 user stories + cross-cutting
- `specs/002-local-api-service/research.md` — FastAPI patterns, subprocess strategy, concurrency model

### Key Decisions
- **Subprocess via transcribe.sh** (not direct binary) — reuses format conversion and validation logic
- **asyncio.Semaphore(1)** for sequential processing — prevents OOM from concurrent binary invocations
- **asyncio.create_subprocess_exec** — non-blocking subprocess to avoid blocking the event loop
- **requirements-api.txt** (not requirements.txt) — isolates API deps from core engine
- **No data-model.md** — stateless API, no persistent storage

### Next Step
Phase 6 (`/tasks`) to generate task breakdown from plan.md

## 2026-02-22: Phase 6-7 Tasks + Audit — 002-local-api-service

- `specs/002-local-api-service/tasks.md` — 20 tasks with TDD steps, AC mapping, dependency graph
- `specs/002-local-api-service/audit-report.md` — PASS (7/7 constitution, 100% FR coverage, 0 blockers)
- GATE 3: PASS

## 2026-02-22: Phase 8 Implementation — 002-local-api-service

### Files Created
- `api/__init__.py` — package init
- `api/config.py` — settings (host, port, temp dir, queue size, max upload, timeout)
- `api/models.py` — Pydantic response models (TranscriptionResponse, HealthResponse, ErrorResponse)
- `api/transcribe.py` — async subprocess wrapper for scripts/transcribe.sh
- `api/main.py` — FastAPI app (POST /transcribe, GET /health, semaphore, temp cleanup)
- `requirements-api.txt` — FastAPI + uvicorn + python-multipart
- `scripts/start-api.sh` — lifecycle script with prerequisite validation
- `scripts/stop-api.sh` — graceful shutdown with PID management
- `tests/test_api.py` — 20 unit tests (config, models, health, transcribe, cleanup)
- `tests/test-api.sh` — integration test script

### Test Results
- 20/20 unit tests passing (0.30s)
- All error codes covered: 200, 400, 413, 429, 500, 503

## 2026-02-22: Phase 5 Planning — 003-medical-feasibility-testing

### Artifacts Created
- `specs/003-medical-feasibility-testing/plan.md` — 17 tasks across 4 user stories + cross-cutting
- `specs/003-medical-feasibility-testing/research.md` — macOS TTS pipeline, grep-based accuracy, /usr/bin/time latency

### Key Decisions
- **TTS voice**: macOS `say -v Samantha` (en_US, natural, no quoting issues)
- **Audio format**: say → AIFF → ffmpeg -ar 16000 -ac 1 → WAV (proper format for binary -i flag)
- **Accuracy matching**: Case-insensitive `grep -iqF` (fixed-string substring match)
- **No synonym engine**: If model says "mg" instead of "milligrams", it counts as MISS
- **Memory measurement**: `/usr/bin/time -l` on macOS (BSD time binary)
- **Latency defaults**: 1min + 5min only; 15min/30min via `--full` flag

## 2026-02-22: Phase 6-7 Tasks + Audit — 003-medical-feasibility-testing

- `specs/003-medical-feasibility-testing/tasks.md` — 17 tasks with AC mapping, dependency graph
- `specs/003-medical-feasibility-testing/audit-report.md` — PASS (7/7 constitution, 100% FR coverage, 0 blockers)
- GATE 3: PASS

## 2026-02-22: Phase 8 Implementation — 003-medical-feasibility-testing

### Files Created
- `tests/medical-audio/*.text` (x5) — TTS input prose per category
- `tests/medical-audio/*.terms.txt` (x5) — Target medical terms (61 total)
- `tests/medical-audio/*.expected.txt` (x5) — Ground truth transcriptions
- `scripts/generate-medical-test-audio.sh` — TTS → WAV generation pipeline
- `tests/test-medical-accuracy.sh` — Accuracy runner with --report flag for feasibility report
- `tests/test-medical-latency.sh` — Latency benchmark with --full flag for long durations

### Test Corpus
5 categories, 61 target terms:
- psychiatric-medications (13): sertraline, fluoxetine, quetiapine, etc.
- diagnoses (12): major depressive disorder, PTSD, bipolar disorder, etc.
- anatomical-terms (11): prefrontal cortex, hippocampus, amygdala, etc.
- vitals-measurements (13): blood pressure, heart rate, oxygen saturation, etc.
- clinical-phrases (12): patient presents with, treatment plan, risk assessment, etc.
