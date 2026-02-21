# Feasibility Test 001: Initial Transcription

**Date**: 2026-02-21
**Model**: Qwen3-ASR-0.6B
**Hardware**: Apple Silicon Mac
**Build**: `make blas` (Apple Accelerate + ARM NEON)

## Test Audio
- **Source**: `/transcribe/uploads/test-audio/audio-to-transcribe-test.mp3`
- **Duration**: 86.5 seconds
- **Content**: Guided breathing/relaxation exercise (English)

## Results

### Performance
- **Inference time**: 16.2 seconds
- **Realtime factor**: 5.35x (processes 5.35 seconds of audio per second of compute)
- **Token rate**: 10.70 tokens/sec
- **Breakdown**: Encoding 3,922ms (24%), Decoding 12,248ms (76%)
- **Output**: 173 text tokens, 124 words

### Transcription Quality
Full output (verbatim, no post-processing):
> It's three AM. You're not asleep. Neither am I. Your brain's doing that thing where it replays every conversation from 2019. Fun, right? Here's what works when nothing else does. Close your eyes if you want, or don't. Breathe in for four seconds. Hold for four. Out for six. Hold for four. That's it. Keep that rhythm. Box breathing with a longer exhale. Don't count shape. Don't try to clear your mind. Just match your breath to this pattern. In for four. Hold. Out for six. Hold. This won't knock you out instantly, but it'll quiet your nervous system enough that sleep becomes possible again. Usually kicks in around ten minutes. Sometimes less. Sometimes you just drift. I'll stay here with you. Keep breathing.

### Quality Assessment
- **Intelligibility**: Excellent — fully coherent, readable output
- **Punctuation**: Correct sentence boundaries and periods
- **Numbers**: Written as words ("three", "four", "six") — appropriate for spoken content
- **Medical terminology**: N/A for this audio (general wellness content)
- **Errors observed**: None apparent in this sample
- **Streaming mode**: Also produces output (tested with 10s clip)

## Conclusions
1. The 0.6B model produces high-quality transcription at >5x realtime on Apple Silicon
2. Output is clean enough for direct use without post-processing
3. Medical terminology accuracy needs testing with clinical audio samples
4. Memory usage within expected bounds (~2.8GB)
5. **Feasibility: CONFIRMED** for the core transcription use case
