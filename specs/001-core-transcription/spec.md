---
feature: 001-core-transcription
created: 2026-02-22
status: ready
priority: P1
---

# Feature: Core Transcription Pipeline

## Overview
Build the upstream C binary via `make blas`, download the Qwen3-ASR-0.6B model weights, and transcribe audio files locally with zero network dependency during inference.

## Problem Statement
**What problem are we solving?**
Cloud-based ASR services require sending patient audio to third-party servers, creating HIPAA compliance liability and data breach risk. Healthcare developers need a fully local, private transcription engine that keeps all audio on-device.

**Who experiences this problem?**
Healthcare developers building compliant clinical applications, psychiatrists and clinicians recording patient sessions, and clinical IT teams responsible for HIPAA compliance posture.

**Current situation and pain points:**
1. Cloud ASR APIs (Google, AWS, Azure) transmit protected health information over the network, requiring BAAs and creating audit surface area
2. Commercial on-premise solutions are expensive, vendor-locked, and often require GPU infrastructure
3. No lightweight, CPU-only, privacy-first ASR option exists that a solo developer can build and run from source in minutes

## User Stories

### US-1: Build and Run Transcription (Priority: P1)
**As a** healthcare developer
**I want to** build the C binary and run transcription locally
**So that** patient audio never leaves the device

**Acceptance Criteria:**
- [ ] AC-1.1: `make blas` produces working binary on macOS with Xcode CLI tools
- [ ] AC-1.2: `./download_model.sh --model small` downloads Qwen3-ASR-0.6B
- [ ] AC-1.3: Binary transcribes WAV at >=3x realtime on Apple Silicon
- [ ] AC-1.4: Output is coherent English text with correct sentence boundaries
**Test:** `bash tests/test-transcription.sh` passes

### US-2: Transcribe Any Audio Format (Priority: P1)
**As a** clinical developer
**I want to** transcribe audio in any common format (mp3, m4a, wav, etc.)
**So that** I don't need to pre-convert recordings

**Acceptance Criteria:**
- [ ] AC-2.1: `scripts/transcribe.sh` converts input to s16le 16kHz mono via ffmpeg
- [ ] AC-2.2: Supports at minimum: WAV, MP3, M4A, FLAC, OGG
- [ ] AC-2.3: Clear error if ffmpeg not installed
- [ ] AC-2.4: Clear error if model not downloaded
**Test:** `bash scripts/transcribe.sh <audio-file>` produces text output

### US-3: Quality Gate Validation (Priority: P2)
**As a** contributor
**I want to** run quality checks before committing
**So that** the build stays green and transcription stays reliable

**Acceptance Criteria:**
- [ ] AC-3.1: `scripts/quality-gate.sh` builds binary and runs smoke tests
- [ ] AC-3.2: Pre-commit hook blocks commits if quality gate fails
- [ ] AC-3.3: All scripts use `set -euo pipefail`
**Test:** `bash scripts/quality-gate.sh` exits 0

## Functional Requirements

### FR-001: Binary Build
**Priority**: P1
**Description**: `make blas` compiles qwen_asr binary using Apple Accelerate BLAS + ARM NEON SIMD

### FR-002: Model Download
**Priority**: P1
**Description**: `download_model.sh` fetches Qwen3-ASR-0.6B weights (~1.9GB) to local directory

### FR-003: Audio Transcription
**Priority**: P1
**Description**: Binary accepts 16-bit PCM 16kHz mono audio and outputs transcribed text

### FR-004: Format Conversion
**Priority**: P1
**Description**: Wrapper script converts any ffmpeg-supported format to required input format

### FR-005: Quality Pipeline
**Priority**: P2
**Description**: Quality gate script validates build + transcription before commits

## Non-Functional Requirements

### NFR-001: Performance
- >=3x realtime transcription on Apple Silicon (measured: 5.35x on M-series)
- Memory usage <4GB for 0.6B model (measured: ~2.8GB)

### NFR-002: Privacy
- Zero network calls during inference
- Audio data never persisted by the transcription engine
- Model weights downloaded once, stored locally

### NFR-003: Reliability
- Clean build from fresh checkout + Xcode CLI tools
- No additional dependencies beyond upstream requirements (gcc, BLAS, pthreads, libm)
- Scripts validate prerequisites before execution

## Constraints & Assumptions
- Upstream C source MUST NOT be modified (fork constraint)
- Requires macOS with Xcode CLI tools for Apple Accelerate
- Requires ffmpeg for non-WAV format support
- Model download requires one-time internet access (~1.9GB)
- [A1] Apple Silicon is the primary target hardware
- [A2] 0.6B model is sufficient for feasibility phase

## Out of Scope
- GPU inference acceleration
- Real-time streaming transcription API
- Multi-language support testing
- 1.7B model evaluation (future phase)
- Post-processing (punctuation correction, speaker diarization)

## Success Criteria
- Binary builds in <60 seconds on M-series Mac
- Transcription accuracy: 0 errors on test audio (validated)
- Realtime factor: >=3x (measured: 5.35x)
- Quality gate passes on clean checkout

## Edge Cases
1. **No Xcode CLI tools**: `make blas` fails with clear error about missing compiler
2. **No ffmpeg installed**: `scripts/transcribe.sh` fails with actionable error message
3. **Model not downloaded**: Binary exits with clear error pointing to download_model.sh
4. **Corrupted model weights**: Binary should fail gracefully (not segfault)
5. **Empty audio file**: Script handles gracefully with meaningful error
6. **Very long audio (>1hr)**: Memory usage stays bounded, no OOM for 0.6B model
