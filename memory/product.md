# Product Definition — qwen-asr

## Product Name
Local Medical Transcription Engine

## Problem Statement
Cloud ASR APIs (OpenAI Whisper, Google STT, etc.) transmit audio to remote servers — a HIPAA liability for medical transcription. Healthcare organizations either pay for expensive BAA-covered services or risk non-compliance. No affordable, privacy-first local solution exists that delivers clinical-grade transcription.

## Solution
A local-first speech-to-text engine built on the antirez/qwen-asr C binary. All audio processing stays on-device. No network calls, no cloud dependencies, no BAA requirements for the transcription layer.

## Value Proposition
- **Privacy-first**: Audio never leaves the device. Zero network calls during inference.
- **Offline-capable**: Works without internet after model download.
- **Fast CPU inference**: 8-13x realtime on Apple Silicon (0.6B model). A 30-minute session transcribes in ~3 minutes.
- **Zero infrastructure cost**: No cloud compute, no API fees, no GPU rental.
- **Simple deployment**: Single C binary + model weights. No Python, no Docker, no venv.

## Target Persona
**Healthcare Developer** building HIPAA-compliant applications that need transcription:
- Psychiatric practice management software
- Clinical note automation tools
- Patient encounter documentation systems
- Telehealth platforms needing local recording + transcription

## User Stories

1. **As a psychiatrist**, I want to record sessions and get transcriptions without sending audio to the cloud, so patient privacy is maintained.
2. **As a clinical developer**, I want a local transcription API I can call from my app, so I don't need cloud ASR vendor lock-in.
3. **As a healthcare IT admin**, I want transcription that runs on standard hardware (no GPU), so deployment is simple.
4. **As a compliance officer**, I want proof that audio data never leaves the device, so HIPAA audits are straightforward.

## Key Metrics (Feasibility Phase)
- Transcription accuracy on medical terminology (target: >90% WER-comparable to Whisper)
- Inference speed on target hardware (target: >3x realtime on M1 Air)
- Memory footprint during inference (target: <4GB for 0.6B model)
- End-to-end latency from audio file to text output

## Competitive Landscape

| Solution | Local? | Cost | Speed | Medical Accuracy |
|----------|--------|------|-------|-----------------|
| OpenAI Whisper API | No | $0.006/min | Fast (cloud) | Good |
| Google STT | No | $0.016/min | Fast (cloud) | Good |
| whisper.cpp | Yes | Free | 3-5x realtime | Good |
| **qwen-asr (this)** | Yes | Free | 8-13x realtime | TBD |

## Roadmap
1. **Phase 1** (current): Feasibility — build, test, measure accuracy and speed
2. **Phase 2**: FastAPI local HTTP wrapper for app integration
3. **Phase 3**: Medical feasibility testing with clinical audio samples
4. **Phase 4**: Production hardening (if feasibility confirmed)
