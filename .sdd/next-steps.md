# SDD Next Steps — qwen-asr

## Feature 001: Core Transcription Pipeline
- **Status**: Implementation complete (pre-existing)
- **Next**: No further SDD phases needed. Spec documents existing, working functionality.
- **Action**: Mark as complete, or proceed to Phase 5 (`/plan`) only if enhancements are planned.

## Feature 002: Local API Service
- **Status**: Specified (GATE 1 PASS)
- **Next**: Phase 5 — `/plan` to create `specs/002-local-api-service/plan.md`
- **Action**: Run `/plan specs/002-local-api-service/spec.md`

## Feature 003: Medical Feasibility Testing
- **Status**: Specified (GATE 1 PASS)
- **Next**: Phase 5 — `/plan` to create `specs/003-medical-feasibility-testing/plan.md`
- **Action**: Run `/plan specs/003-medical-feasibility-testing/spec.md`

## Recommended Execution Order

1. **002 (Local API)** — Provides the HTTP interface other tools depend on
2. **003 (Medical Testing)** — Can use either CLI or API for testing
3. **001 (Core)** — Already done; revisit only if enhancements needed
