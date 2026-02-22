# Implementation Plan: 003-medical-feasibility-testing

**Spec**: spec.md | **Status**: Ready | **GATE 1**: PASS | **GATE 2**: SKIP

## Overview

Build a shell-script test suite that evaluates qwen-asr accuracy on medical terminology. Uses macOS TTS to generate controlled test audio across 5 medical vocabulary categories (61 terms total), transcribes with the engine, measures per-category and overall accuracy via case-insensitive substring matching, and produces a structured feasibility report with go/no-go recommendation.

## Architecture

```
scripts/generate-medical-test-audio.sh
  └─ For each of 5 categories: say -v Samantha → AIFF → ffmpeg → WAV

tests/test-medical-accuracy.sh
  └─ For each category: transcribe → grep -iqF terms → report per-category + overall
  └─ --report flag: generate docs/feasibility/002-medical-terminology-test.md

tests/test-medical-latency.sh (P2)
  └─ For each duration (1m, 5m): generate long audio → transcribe → parse timing
  └─ --full flag: also test 15m, 30m
```

## Dependencies

| Dep | Type | Status |
|-----|------|--------|
| qwen_asr binary | Internal | Exists (make blas) |
| qwen3-asr-0.6b model | Internal | Exists |
| ffmpeg | System | Assumed present |
| macOS `say` command | System | macOS only |
| scripts/transcribe.sh | Internal | Exists |
| /usr/bin/time | System | macOS BSD time |

## Tasks by User Story

### US-2: Generate Test Audio Samples (P1)

| ID | Task | Est. | Deps |
|----|------|------|------|
| T1.1 | Create test data files (5 × .text, .terms.txt, .expected.txt) | M | - |
| T1.2 | Write `scripts/generate-medical-test-audio.sh` — TTS → WAV pipeline | M | T1.1 |
| T1.3 | Test: script generates 5 WAV files from .text inputs | S | T1.2 |

### US-1: Test Medical Terminology Accuracy (P1)

| ID | Task | Est. | Deps |
|----|------|------|------|
| T2.1 | Write `tests/test-medical-accuracy.sh` — accuracy runner | M | T1.2 |
| T2.2 | Implement per-category accuracy calculation (grep -iqF matching) | S | T2.1 |
| T2.3 | Implement overall accuracy summary | S | T2.2 |
| T2.4 | Test: script runs and reports per-category + overall accuracy | S | T2.3 |

### US-4: Produce Feasibility Report (P1)

| ID | Task | Est. | Deps |
|----|------|------|------|
| T3.1 | Add `--report` flag to test-medical-accuracy.sh | M | T2.3 |
| T3.2 | Generate `docs/feasibility/002-medical-terminology-test.md` with all sections | M | T3.1 |
| T3.3 | Test: report contains methodology, results, go/no-go recommendation | S | T3.2 |

### US-3: Measure Latency with Clinical Audio (P2)

| ID | Task | Est. | Deps |
|----|------|------|------|
| T4.1 | Write `tests/test-medical-latency.sh` — latency benchmark | M | T1.2 |
| T4.2 | Implement 1min + 5min duration tests with /usr/bin/time -l | M | T4.1 |
| T4.3 | Add `--full` flag for 15min + 30min durations | S | T4.2 |
| T4.4 | Test: script reports timing and memory for each duration | S | T4.2 |

### Cross-Cutting: Git + SDD

| ID | Task | Est. | Deps |
|----|------|------|------|
| T5.1 | Create SDD artifacts (plan.md, research.md, tasks.md, audit-report.md) | S | - |
| T5.2 | Update SDD state files (.sdd/, todos/) | S | T5.1 |
| T5.3 | Commit and push | S | T4.4 |

## File Map

| File | Action | Task |
|------|--------|------|
| `tests/medical-audio/*.text` (x5) | Create | T1.1 |
| `tests/medical-audio/*.terms.txt` (x5) | Create | T1.1 |
| `tests/medical-audio/*.expected.txt` (x5) | Create | T1.1 |
| `scripts/generate-medical-test-audio.sh` | Create | T1.2 |
| `tests/test-medical-accuracy.sh` | Create | T2.1 |
| `tests/test-medical-latency.sh` | Create | T4.1 |
| `docs/feasibility/002-medical-terminology-test.md` | Generated | T3.2 |
| `specs/003-medical-feasibility-testing/plan.md` | Create | T5.1 |
| `specs/003-medical-feasibility-testing/research.md` | Create | T5.1 |
| `specs/003-medical-feasibility-testing/tasks.md` | Create | T5.1 |
| `specs/003-medical-feasibility-testing/audit-report.md` | Create | T5.1 |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| macOS `say` mispronounces medical terms | Inaccurate TTS audio | Document TTS issues; note real speech may differ |
| Model outputs phonetic rather than correct spelling | Wrong accuracy results | This IS what we're testing — document as finding |
| 30-min TTS generation is slow | Long test runs | Default to 1m+5m; long durations opt-in via --full |
| grep substring matching overclaims | Inflated accuracy | Multi-word terms are specific enough; document methodology |

## Testing Strategy

- **Audio generation**: Visual check that WAV files are created and non-empty
- **Accuracy test**: Run against generated audio, verify per-category + overall output
- **Latency test**: Run 1min + 5min tests, verify timing output
- **Report**: Verify generated report has all required sections

## Build Sequence

1. T1.1 (test data files — already created)
2. T1.2 + T5.1 (parallel — audio gen script + SDD artifacts)
3. T2.1-T2.3 (accuracy script)
4. T3.1-T3.2 (report generation)
5. T4.1-T4.3 (latency script)
6. T1.3, T2.4, T3.3, T4.4 (verification)
7. T5.2-T5.3 (state updates + git)
