# Research: 003-medical-feasibility-testing

## macOS TTS for Test Audio Generation

**Tool**: `say -v Samantha` (macOS built-in, en_US, natural female voice)
**Pipeline**: `say -v Samantha -o temp.aiff < input.text && ffmpeg -i temp.aiff -ar 16000 -ac 1 output.wav`

**Why Samantha**: Consistent, clear enunciation. Available on all macOS versions. No quoting issues with medical terms. Alternative voices (Alex, Victoria) tested but Samantha best balances clarity and naturalness.

**Format chain**: `say` outputs AIFF natively. Direct WAV output from `say` uses non-standard headers that qwen_asr may reject. AIFF → ffmpeg → WAV (16kHz mono s16le) produces clean, compatible files.

**Pitfall**: `say` may mispronounce some medical terms (e.g., "quetiapine" as "kweh-TIE-uh-pine" instead of "kweh-TY-uh-peen"). This is acceptable — we're testing the ASR model, not the TTS engine. Document any known TTS pronunciation issues.

## Accuracy Measurement: grep -iqF

**Method**: Case-insensitive fixed-string substring match (`grep -iqF "$term"`)
**Input**: Transcription text from qwen_asr (stdout, --silent mode)
**Terms file**: One term per line in `.terms.txt` files

**Why not WER**: Word Error Rate is overkill for feasibility. We need "does the model recognize these specific medical terms?" — binary hit/miss per term is sufficient and more actionable.

**Why not regex**: Fixed-string match avoids regex escaping issues with medical terms containing parentheses, dots, etc. Case-insensitive handles capitalization differences.

**Overclaiming risk**: Multi-word terms like "major depressive disorder" are specific enough that substring matching is reliable. Single-word terms like "lithium" could match in non-medical context, but our test audio is all medical content.

**No synonym mapping**: The plan explicitly states no synonym engine. If the model says "mg" instead of "milligrams", it counts as a MISS. This documents the model's actual behavior rather than inflating accuracy.

## Latency Measurement: /usr/bin/time -l

**Tool**: BSD `/usr/bin/time -l` (not shell builtin `time`)
**Why**: Provides wall-clock time, user/system CPU time, AND peak memory (maximum resident set size). The shell builtin only provides timing.

**Parsing**:
- Wall time: first line, format `real X.XX` or `X.XX real`
- Peak memory: line containing `maximum resident set size`, value in bytes (macOS) → convert to MB
- Note: macOS `/usr/bin/time -l` reports bytes, not KB like Linux

**Timing from qwen_asr stderr**:
```
Inference: <ms> ms, <tokens> text tokens (<tok/s> tok/s, encoding: <ms>ms, decoding: <ms>ms)
Audio: <audio_s> s processed in <infer_s> s (<x>x realtime)
```
Parse the "Audio:" line for realtime factor. This is more precise than wall-clock time since it excludes model loading.

## Long Audio Generation for Latency Tests

**Approach**: Concatenate category WAVs + generate additional TTS to reach target durations.
- 1min: Concatenate all 5 category WAVs (each ~20-30s from TTS) with `ffmpeg -filter_complex concat`
- 5min: Generate additional TTS from repeated/extended clinical prose, concatenate
- 15min/30min: Only via `--full` flag due to real-time TTS generation time

**Alternative considered**: Loop a single WAV file. Rejected — repeated identical audio isn't a realistic test of medical transcription.

## Test Corpus Design

**5 categories, 61 terms**: Chosen to cover the key medical vocabulary domains mentioned in the spec:
1. Psychiatric medications (13) — Drug names are the hardest test: unusual phonetics, brand/generic confusion
2. Diagnoses (12) — Multi-word clinical terms, some with abbreviation alternatives
3. Anatomical terms (11) — Latin/Greek-derived terms, compound phrases
4. Vitals & measurements (13) — Numbers in context, units, abbreviations
5. Clinical phrases (12) — Common clinical workflow language, should be easier for the model

**Prose style**: Natural clinical dictation — complete sentences a psychiatrist might speak during documentation. Not isolated word lists (too artificial) or dense medical texts (not realistic for ASR input).
