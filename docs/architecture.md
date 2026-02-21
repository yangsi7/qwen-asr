# qwen-asr Architecture

## Overview

Pure C inference engine for Qwen3-ASR speech-to-text. Zero Python, zero PyTorch dependencies at runtime. Single compiled binary with Apple Accelerate (macOS) or OpenBLAS (Linux) for BLAS acceleration.

## Data Flow

```
Audio Input (WAV/stdin s16le)
    │
    ▼
Resampling → 16kHz mono
    │
    ▼
128-bin Mel Spectrogram
    │
    ▼
Conv2D Stem (3 layers, 8x time downsample, 480 channels)
    │
    ▼
Audio Encoder (Transformer)
  - Bidirectional windowed attention (8s windows)
  - Sinusoidal positional encoding per 100-frame chunk
  - 0.6B: 18 layers, dim 896
  - 1.7B: 24 layers, dim 1024
    │
    ▼
Projection (Linear → GELU → Linear)
    │
    ▼
Qwen3 LLM Decoder
  - Grouped Query Attention (16Q/8KV)
  - Per-head Q/K RMSNorm before RoPE
  - NeoX RoPE, SwiGLU FFN
  - KV cache with prefill reuse
  - 0.6B: 28 layers, dim 1024
  - 1.7B: 28 layers, dim 2048
    │
    ▼
BPE Tokenizer → Text Output (stdout)
```

## Source File Map

| File | Responsibility |
|------|---------------|
| `main.c` | CLI parsing, defaults, callback wiring, reporting |
| `qwen_asr.c` | High-level transcription orchestration (offline, segmented, streaming) |
| `qwen_asr.h` | Public API, runtime state struct |
| `qwen_asr_encoder.c` | Audio tower: load weights + forward pass |
| `qwen_asr_decoder.c` | LLM decoder: load, prefill, token step, KV cache |
| `qwen_asr_audio.c` | WAV/stdin decode, resampling, mel spectrogram |
| `qwen_asr_tokenizer.c` | BPE tokenizer encode/decode |
| `qwen_asr_safetensors.c` | Safetensors format loading + mmap |
| `qwen_asr_kernels.c` | Common math, threading, BLAS dispatch |
| `qwen_asr_kernels_neon.c` | ARM NEON optimized hot loops |
| `qwen_asr_kernels_avx.c` | x86 AVX optimized hot loops |
| `qwen_asr_kernels_generic.c` | Fallback generic kernels |
| `qwen_asr_kernels_impl.h` | Architecture dispatch macros |

## Runtime Modes

### Offline Full-Context (`-S 0`, default)
Processes entire audio as one chunk. Best quality, memory grows with audio length.

### Offline Segmented (`-S <secs>`)
Splits audio at low-energy boundaries within `-W` window. Best speed for long files. Memory capped.

### Streaming (`--stream`)
Processes audio in 2s chunks with encoder cache reuse and prefix rollback. Suitable for live audio. Slower than segmented for pre-recorded files.

## Model Formats

| Model | Parameters | Weight Size | Memory Usage |
|-------|-----------|-------------|-------------|
| 0.6B | ~600M | ~1.9 GB | ~2.8 GiB |
| 1.7B | ~1.7B | ~4.7 GB | ~6.7 GiB |

Encoder weights: f32 (converted at load). Decoder weights: bf16 mmapped.

## Build Pipeline

```bash
make blas          # Build with Accelerate (macOS) / OpenBLAS (Linux)
make debug         # Debug build with AddressSanitizer
make clean         # Remove artifacts
make test          # Run regression suite (requires 1.7B model)
```

Compiler: gcc with `-O3 -march=native -ffast-math`
