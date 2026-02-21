---
feature: 003-medical-feasibility-testing
created: 2026-02-22
status: ready
priority: P1
---

# Feature: Medical Feasibility Testing

## Overview

Systematic evaluation of qwen-asr transcription accuracy on medical terminology. Tests pronunciation of drug names, anatomical terms, diagnostic codes, and clinical phrases to determine viability for medical transcription workflows. Produces a structured feasibility report with per-category accuracy metrics.

## Problem Statement

**What problem are we solving?**
The initial feasibility test (001) validated transcription quality on general English audio. Medical transcription requires accurate handling of specialized vocabulary: drug names (e.g., "metformin", "sertraline"), anatomical terms (e.g., "anterior cruciate ligament"), diagnostic language (e.g., "bilateral pneumothorax"), and clinical abbreviations. Without testing these, we can't confirm the engine is viable for healthcare use.

**Who experiences this problem?**
- Psychiatrists relying on accurate medication name transcription
- Clinical developers who need confidence in medical term accuracy before building on the engine
- Compliance officers who need documented accuracy metrics for HIPAA risk assessment

**Current situation and pain points:**
- Only general English audio tested — zero medical terminology data points
- No structured test corpus for medical vocabulary
- No benchmarking methodology for ongoing accuracy tracking
- Cannot make go/no-go decisions without medical accuracy data

## User Stories

### US-1: Test Medical Terminology Accuracy (Priority: P1)
**As a** clinical developer
**I want to** see transcription accuracy metrics for medical vocabulary categories
**So that** I can decide if the engine is viable for my healthcare application

**Acceptance Criteria:**
- [ ] AC-1.1: Test corpus includes ≥5 audio samples with medical terminology
- [ ] AC-1.2: Categories tested: medication names, anatomical terms, diagnoses, clinical phrases
- [ ] AC-1.3: Per-category accuracy (correct/total terms) is calculated and documented
- [ ] AC-1.4: Overall accuracy across all medical terms is reported
- [ ] AC-1.5: Results compared against expected reference transcriptions
**Test:** `bash tests/test-medical-accuracy.sh` runs all samples and reports metrics

### US-2: Generate Test Audio Samples (Priority: P1)
**As a** a tester
**I want to** create standardized audio samples containing medical terms
**So that** accuracy testing is reproducible and covers key terminology categories

**Acceptance Criteria:**
- [ ] AC-2.1: Script generates or documents how to obtain test audio with medical terms
- [ ] AC-2.2: Each audio sample has a reference transcription (ground truth)
- [ ] AC-2.3: Samples cover: psychiatric medications, common diagnoses, anatomical terms, vital signs, clinical workflow phrases
- [ ] AC-2.4: Audio format matches engine requirements (WAV 16kHz mono or convertible)
**Test:** Audio files exist in `tests/medical-audio/` with matching `.expected.txt` files

### US-3: Measure Latency with Clinical Audio (Priority: P2)
**As a** healthcare IT admin
**I want to** know transcription latency for realistic clinical audio lengths
**So that** I can plan deployment for real-world session recordings

**Acceptance Criteria:**
- [ ] AC-3.1: Test with audio durations: 1min, 5min, 15min, 30min
- [ ] AC-3.2: Report realtime factor for each duration
- [ ] AC-3.3: Report memory usage during transcription
- [ ] AC-3.4: Confirm no degradation for longer audio files
**Test:** `bash tests/test-medical-latency.sh` reports timing for each duration

### US-4: Produce Feasibility Report (Priority: P1)
**As a** product stakeholder
**I want to** read a structured feasibility report with go/no-go recommendation
**So that** I can decide whether to proceed with the local API service (spec 002)

**Acceptance Criteria:**
- [ ] AC-4.1: Report includes: methodology, test corpus description, results per category
- [ ] AC-4.2: Report includes overall accuracy, latency measurements, and memory metrics
- [ ] AC-4.3: Report has clear go/no-go recommendation with criteria
- [ ] AC-4.4: Report saved to `docs/feasibility/002-medical-terminology-test.md`
**Test:** Report file exists and contains all required sections

## Functional Requirements

### FR-001: Test Corpus
**Priority**: P1
**Description**: Collection of audio samples with medical terminology, each paired with reference transcription for accuracy comparison

### FR-002: Accuracy Measurement Script
**Priority**: P1
**Description**: Script that transcribes test corpus, compares to reference, calculates per-category and overall accuracy metrics

### FR-003: Latency Benchmark
**Priority**: P2
**Description**: Script that measures transcription time and memory usage across various audio durations

### FR-004: Feasibility Report Generation
**Priority**: P1
**Description**: Structured report documenting test methodology, results, and go/no-go recommendation

### FR-005: Terminology Categories
**Priority**: P1
**Description**: Test coverage across these categories:
- Psychiatric medications (SSRIs, SNRIs, antipsychotics, benzodiazepines)
- Common diagnoses (depression, anxiety, PTSD, bipolar disorder, schizophrenia)
- Anatomical terms (prefrontal cortex, hippocampus, amygdala)
- Vital signs and measurements (blood pressure, heart rate, BMI, dosage units)
- Clinical workflow phrases ("patient presents with", "differential diagnosis", "treatment plan")

## Non-Functional Requirements

### NFR-001: Reproducibility
- All tests runnable from a single script
- Reference transcriptions version-controlled alongside audio metadata
- Test results deterministic (same audio → same transcription)

### NFR-002: Privacy
- Test audio must not contain real patient data
- Use synthetic or public-domain medical audio only
- Audio samples can be TTS-generated for controlled testing

### NFR-003: Documentation
- All methodology documented for reproducibility
- Results traceable to specific audio files and model version

## Technical Approach

### Test Audio Sources
1. **TTS-generated**: Use macOS `say` command or similar to generate controlled medical term audio
2. **Public datasets**: Medical lecture excerpts (Creative Commons)
3. **Synthetic clinical notes**: Script reads synthetic clinical scenarios aloud via TTS

### Accuracy Calculation
```
Per-term accuracy: correct_terms / total_terms * 100
Per-category accuracy: correct_in_category / total_in_category * 100
Overall: correct_all / total_all * 100
```

Comparison method: case-insensitive exact match on medical terms, with common variant mapping (e.g., "mg" = "milligrams")

### Directory Structure
```
tests/
  medical-audio/                        # Test audio files (gitignored if large)
    psychiatric-medications.wav
    psychiatric-medications.expected.txt
    diagnoses.wav
    diagnoses.expected.txt
    anatomical-terms.wav
    anatomical-terms.expected.txt
    clinical-phrases.wav
    clinical-phrases.expected.txt
    vitals-measurements.wav
    vitals-measurements.expected.txt
  test-medical-accuracy.sh              # Accuracy test runner
  test-medical-latency.sh              # Latency benchmark
scripts/
  generate-medical-test-audio.sh        # TTS generation for test corpus
docs/
  feasibility/
    002-medical-terminology-test.md     # Results report
```

## Constraints & Assumptions
- Test audio may be TTS-generated (not real patient recordings)
- macOS `say` or equivalent TTS is available for audio generation
- Ground truth transcriptions are manually verified
- [A1] TTS-generated audio is a reasonable proxy for natural speech accuracy
- [A2] The 0.6B model is the target for feasibility testing
- [A3] Accuracy >85% on medical terms is the minimum viable threshold

## Out of Scope
- Real patient audio testing (HIPAA considerations)
- Speaker diarization accuracy
- Accent/dialect variation testing
- Non-English medical terminology
- Comparison benchmarks against Whisper or Google STT
- Automated WER calculation tools (manual comparison is sufficient for feasibility)

## Success Criteria

### Go Criteria (all must pass)
- Overall medical term accuracy ≥85%
- No category below 70% accuracy
- Realtime factor ≥3x maintained with medical content
- Memory usage stays <4GB

### No-Go Indicators
- Overall accuracy <70%
- Any critical category (medications, diagnoses) below 60%
- Significant performance degradation vs. general audio
- Model hallucinations on medical terms (fabricating plausible but wrong terms)

## Edge Cases
1. **Homophone medical terms**: "ileum" vs "ilium" — document which the model produces
2. **Drug name spelling**: "sertraline" vs "Zoloft" (brand vs generic) — test both
3. **Abbreviated terms**: "BP", "HR", "BMI" — test if model expands or preserves
4. **Numbers in context**: "100mg twice daily" — test dosage transcription accuracy
5. **Multi-word medical phrases**: "major depressive disorder" — test as unit
6. **Rapid clinical speech**: Test with faster-paced dictation-style audio
