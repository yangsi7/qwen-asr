# Tasks: 003-medical-feasibility-testing

**Plan**: plan.md | **Total**: 17 | **Completed**: 0

## Progress Summary
| User Story | Tasks | Done | Status |
|------------|-------|------|--------|
| US-2: Generate Audio | 3 | 0 | Pending |
| US-1: Accuracy Test | 4 | 0 | Pending |
| US-4: Feasibility Report | 3 | 0 | Pending |
| US-3: Latency Benchmark | 4 | 0 | Pending |
| Cross-Cutting | 3 | 0 | Pending |

---

## US-2: Generate Test Audio Samples (P1)

### T1.1: Create Test Data Files
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: None
- **ACs**:
  - [ ] AC-T1.1.1: 5 `.text` files exist in `tests/medical-audio/`
  - [ ] AC-T1.1.2: 5 `.terms.txt` files exist with target terms (61 total)
  - [ ] AC-T1.1.3: 5 `.expected.txt` files exist with ground truth transcriptions
  - [ ] AC-T1.1.4: Categories: psychiatric-medications, diagnoses, anatomical-terms, vitals-measurements, clinical-phrases

### T1.2: Write Audio Generation Script
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T1.1
- **ACs**:
  - [ ] AC-T1.2.1: `scripts/generate-medical-test-audio.sh` exists with `set -euo pipefail`
  - [ ] AC-T1.2.2: Uses `say -v Samantha` for TTS generation (→ AC-2.1)
  - [ ] AC-T1.2.3: Converts AIFF → WAV via ffmpeg (16kHz mono) (→ AC-2.4)
  - [ ] AC-T1.2.4: Has `--help` flag with usage text
  - [ ] AC-T1.2.5: Checks prerequisites (say, ffmpeg)

### T1.3: Verify Audio Generation
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T1.2
- **ACs**:
  - [ ] AC-T1.3.1: Running script creates 5 WAV files (→ AC-2.1)
  - [ ] AC-T1.3.2: All WAV files are non-empty
  - [ ] AC-T1.3.3: WAV files playable by ffprobe

---

## US-1: Test Medical Terminology Accuracy (P1)

### T2.1: Write Accuracy Test Script
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T1.2
- **ACs**:
  - [ ] AC-T2.1.1: `tests/test-medical-accuracy.sh` exists with `set -euo pipefail`
  - [ ] AC-T2.1.2: Has `--help` flag with usage text
  - [ ] AC-T2.1.3: Checks prerequisites (binary, model, WAV files)

### T2.2: Implement Per-Category Accuracy
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T2.1
- **ACs**:
  - [ ] AC-T2.2.1: Transcribes each category WAV via qwen_asr -i (→ AC-1.1, AC-1.2)
  - [ ] AC-T2.2.2: Matches terms via grep -iqF (→ AC-1.5)
  - [ ] AC-T2.2.3: Reports HIT/MISS per term (→ AC-1.3)
  - [ ] AC-T2.2.4: Reports per-category accuracy percentage (→ AC-1.3)

### T2.3: Implement Overall Accuracy Summary
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T2.2
- **ACs**:
  - [ ] AC-T2.3.1: Reports overall accuracy across all 61 terms (→ AC-1.4)
  - [ ] AC-T2.3.2: Lists per-category summary table

### T2.4: Verify Accuracy Test
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T2.3
- **ACs**:
  - [ ] AC-T2.4.1: Script runs to completion without errors
  - [ ] AC-T2.4.2: Output shows per-category + overall accuracy

---

## US-4: Produce Feasibility Report (P1)

### T3.1: Add --report Flag
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T2.3
- **ACs**:
  - [ ] AC-T3.1.1: `--report` flag triggers report generation (→ AC-4.4)
  - [ ] AC-T3.1.2: Report includes methodology section (→ AC-4.1)
  - [ ] AC-T3.1.3: Report includes per-category results (→ AC-4.1)

### T3.2: Generate Full Report
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: M | **Deps**: T3.1
- **ACs**:
  - [ ] AC-T3.2.1: Report saved to `docs/feasibility/002-medical-terminology-test.md` (→ AC-4.4)
  - [ ] AC-T3.2.2: Report includes accuracy and latency metrics (→ AC-4.2)
  - [ ] AC-T3.2.3: Report includes go/no-go recommendation (→ AC-4.3)

### T3.3: Verify Report
- **Status**: [ ] Pending
- **Priority**: P1
- **Est**: S | **Deps**: T3.2
- **ACs**:
  - [ ] AC-T3.3.1: Report file exists after running with --report
  - [ ] AC-T3.3.2: Report contains all required sections

---

## US-3: Measure Latency with Clinical Audio (P2)

### T4.1: Write Latency Test Script
- **Status**: [ ] Pending
- **Priority**: P2
- **Est**: M | **Deps**: T1.2
- **ACs**:
  - [ ] AC-T4.1.1: `tests/test-medical-latency.sh` exists with `set -euo pipefail`
  - [ ] AC-T4.1.2: Has `--help` flag with usage text
  - [ ] AC-T4.1.3: Checks prerequisites (binary, model, ffmpeg, /usr/bin/time)

### T4.2: Implement Duration Tests
- **Status**: [ ] Pending
- **Priority**: P2
- **Est**: M | **Deps**: T4.1
- **ACs**:
  - [ ] AC-T4.2.1: Tests 1min and 5min audio durations (→ AC-3.1)
  - [ ] AC-T4.2.2: Reports realtime factor for each duration (→ AC-3.2)
  - [ ] AC-T4.2.3: Reports peak memory usage via /usr/bin/time -l (→ AC-3.3)

### T4.3: Add --full Flag
- **Status**: [ ] Pending
- **Priority**: P2
- **Est**: S | **Deps**: T4.2
- **ACs**:
  - [ ] AC-T4.3.1: `--full` flag adds 15min and 30min tests (→ AC-3.1)
  - [ ] AC-T4.3.2: Confirms no degradation for longer audio (→ AC-3.4)

### T4.4: Verify Latency Test
- **Status**: [ ] Pending
- **Priority**: P2
- **Est**: S | **Deps**: T4.2
- **ACs**:
  - [ ] AC-T4.4.1: Script runs to completion for 1min + 5min
  - [ ] AC-T4.4.2: Output shows timing and memory for each duration

---

## Cross-Cutting: SDD + Git

### T5.1: Create SDD Artifacts
- **Status**: [ ] Pending
- **Priority**: P0
- **Est**: S | **Deps**: None
- **ACs**:
  - [ ] AC-T5.1.1: plan.md exists
  - [ ] AC-T5.1.2: research.md exists
  - [ ] AC-T5.1.3: tasks.md exists
  - [ ] AC-T5.1.4: audit-report.md exists

### T5.2: Update SDD State Files
- **Status**: [ ] Pending
- **Priority**: P0
- **Est**: S | **Deps**: T5.1
- **ACs**:
  - [ ] AC-T5.2.1: `.sdd/active-feature.md` set to 003
  - [ ] AC-T5.2.2: `.sdd/features/003-*/state.md` updated
  - [ ] AC-T5.2.3: `.sdd/audit-trail.md` appended
  - [ ] AC-T5.2.4: `.sdd/next-steps.md` updated
  - [ ] AC-T5.2.5: `todos/master-todo.md` updated

### T5.3: Git Workflow
- **Status**: [ ] Pending
- **Priority**: P0
- **Trigger**: After all tasks complete
- **ACs**:
  - [ ] AC-T5.3.1: All tests pass
  - [ ] AC-T5.3.2: All code committed and pushed

---

## Dependency Graph
```
T1.1 → T1.2 → T1.3
              → T2.1 → T2.2 → T2.3 → T2.4
                                     → T3.1 → T3.2 → T3.3
              → T4.1 → T4.2 → T4.3
                       → T4.4
T5.1 → T5.2 → T5.3
```

## Parallelization
| Group | Tasks | Reason |
|-------|-------|--------|
| 1 | T1.1, T5.1 | Independent |
| 2 | T1.2 | Needs test data |
| 3 | T2.1, T4.1 | Independent after audio gen |
| 4 | T3.1 | Needs accuracy logic |
